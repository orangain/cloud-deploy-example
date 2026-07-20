# Cloud Deploy example

`main` への push で、変更された `apps/*` だけを staging へ並列デプロイし、
動作確認後に同じ Cloud Deploy release を production へ昇格するサンプルです。

## 構成

```text
apps/
  hello-service/       DockerfileでビルドするCloud Run service
  hello-function/      DockerfileでビルドするCloud Run function
  hello-ko-service/    koでビルドするGo Cloud Run service
scripts/
  changed-apps.sh      git diff からデプロイ対象を抽出
  select-build-config.sh  appのファイルからCloud Build設定を選択
terraform/             API、IAM、WIF、Cloud Deploy pipeline/target
```

Cloud Deploy の Cloud Run target は 1 target につき 1 service なので、
service ごとに独立した delivery pipeline を作ります。GitHub Actions の matrix が
変更された pipeline を同時実行します。これにより、変更のない service はリリース
されず、失敗や production 昇格も service 単位で扱えます。

コンテナは`cloudbuild/docker.yaml`または`cloudbuild/ko.yaml`を使ってCloud Build
でビルドし、`artifact_project_id`のArtifact Registryへ保存します。workflowは
Dockerfileまたはgo.modからビルダーを選び、Artifact Registryで解決したdigestを
Cloud Deploy releaseへ渡します。Cloud BuildのログはCloud Loggingだけに保存します。
ビルダー判定は`scripts/select-build-config.sh`に集約し、未対応または複数候補が
あるappはエラーにします。判定ロジックは`scripts/select-build-config.test.sh`で
単体テストできます。

## 初期セットアップ

前提:

- `staging_project_id`と`production_project_id`に指定するprojectが作成済み
- `deploy_project_id`にCloud Deployのcontrol projectを指定可能
- Terraform を実行する主体が各 project の IAM/API を管理可能

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# github_repository を実際の owner/repository に変更
terraform init
terraform plan
terraform apply
```

必要に応じて `production_approvers` に production rollout を承認する group/user を
指定してください。指定したメンバーにはCloud Build Approverだけが付与されます。
GitHub Actionsのサービスアカウントには承認権限を付与しません。
Artifact RegistryをCloud Deployとは別のprojectに置く場合は`artifact_project_id`を
指定します。同じprojectに置く場合も`deploy_project_id`と同じ値を明示します。
別projectを指定する場合、Terraformを実行する主体にはそのprojectでAPI、repository、
IAMを管理する権限も必要です。
既存環境でprojectを変更すると新しいrepositoryが作られますが、既存imageはコピー
されないため、変更後に各appを再buildしてください。

apply 後の output を GitHub repository variables に設定します。

| GitHub variable | Terraform output |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `github_workload_identity_provider` |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github_deployer_service_account` |
| `GCP_DEPLOY_PROJECT` | `deploy_project_id` |
| `GCP_ARTIFACT_PROJECT` | `artifact_project_id` |
| `GCP_DEPLOY_REGION` | `region` |

`main` への pull request merge（または直接 push）で
`.github/workflows/release.yml` が staging release を作ります。
release source はTerraformで作成したCloud Deploy用bucketの`source/<app>`へ
アップロードされます。Cloud Build sourceも同じbucketの`build-source/<app>`へ
アップロードし、Google管理のdefault source bucketには依存しません。
GitHub SAのStorage権限はこのbucketだけに限定しています。

Cloud Run serviceはHelm templateの
`run.googleapis.com/invoker-iam-disabled: "true"`により未認証でアクセスできます。
また、Binary Authorizationで`deploy_project_id`のCloud Buildによる検証済み
provenanceを持つimageだけをデプロイできます。
Cloud DeployのstageがSkaffoldの`stg`/`prod` profileを選び、profileに対応する
Helm valuesから次の環境変数が設定されます。

各stageではデプロイ後にCloud Deployのverify taskを実行します。Cloud Deployから
渡される`CLOUD_RUN_SERVICE_URLS`へ`curl`し、HTTPエラーになった場合はrolloutも
失敗します。stagingのverifyが成功するまでproductionへの自動昇格は行われません。

| Environment | `APP_ENV` |
|---|---|
| staging | `stg` |
| production | `prod` |

レスポンスの`message`は各app固有のデフォルト値を使用し、`environment`で
stagingとproductionを区別します。

環境変数を増やす場合は、各appの`values/stg.yaml`と`values/prod.yaml`へ追加します。
TerraformやHelm templateへの変数ごとの追加は不要です。機密値はvaluesへ直接書かず、
Secret Manager参照としてtemplateへ設定してください。

## production へ昇格

staging rolloutが成功すると、Cloud Deploy Automationが同じreleaseをproductionへ
自動的にpromoteします。production targetは`require_approval = true`なので、
実際のproductionデプロイは承認されるまで開始されません。

GitHub Actionsは変更service一覧をPub/Subへ発行し、承認必須の
**approve-production-batch** Cloud Buildを1件作成します。stagingの動作確認後、
Google Cloud consoleのCloud Build履歴からこのbuildを1回承認してください。
専用のbatch approver SAが、同じreleaseに属するproduction rolloutを一括承認します。

承認者が持つのは`roles/cloudbuild.builds.approver`、batch approver SAが持つのは
`roles/clouddeploy.approver`と、gcloudがpipeline情報を取得するための読み取り専用
`roles/clouddeploy.viewer`です。Cloud Deployの監査ログにはbatch approver SAが、
Cloud Buildの監査ログには実際にbuildを承認したユーザーが記録されます。

## service を追加する

1. `apps/<app>/skaffold.yaml`、Helm chart、環境別valuesを追加する
2. `terraform/main.tf` の `local.services` に `<app>` を追加する
3. Terraform を apply する

`apps/<app>/**` の変更は自動検出されます。共通デプロイコード
（`scripts/**`、`.github/workflows/release.yml`）の変更時は全 service が対象です。

## コンテナ image について

初期 manifest は Artifact Registry 不要の公開 Cloud Run hello image を使っています。
`hello-function` には実際の function source と Dockerfile も含めています。実運用時は
CI で image を build/push し、`gcloud deploy releases create` の
`--images=APP_IMAGE=...@sha256:...` で digest を渡してください。
