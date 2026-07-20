# Cloud Deploy example

`main` への push で、変更された `apps/*` だけを staging へ並列デプロイし、
動作確認後に同じ Cloud Deploy release を production へ昇格するサンプルです。

## 構成

```text
apps/
  hello-service/       Cloud Run service
  hello-function/      Functions Framework を使う Cloud Run function
scripts/
  changed-apps.sh      git diff からデプロイ対象を抽出
  create-release.sh    staging release を作成
  promote-release.sh   production へ promote
terraform/             API、IAM、WIF、Cloud Deploy pipeline/target
```

Cloud Deploy の Cloud Run target は 1 target につき 1 service なので、
service ごとに独立した delivery pipeline を作ります。GitHub Actions の matrix が
変更された pipeline を同時実行します。これにより、変更のない service はリリース
されず、失敗や production 昇格も service 単位で扱えます。

## 初期セットアップ

前提:

- `cloud-deploy-example-stg` と `cloud-deploy-example-prod` が作成済み
- Cloud Deploy の control project として `orange-sandbox` を利用
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
指定してください。GitHub Actions のサービスアカウントには承認権限を付与しません。

apply 後の output を GitHub repository variables に設定します。

| GitHub variable | Terraform output |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `github_workload_identity_provider` |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github_deployer_service_account` |
| `GCP_DEPLOY_PROJECT` | `deploy_project_id` |
| `GCP_DEPLOY_REGION` | `region` |

`main` への pull request merge（または直接 push）で
`.github/workflows/release.yml` が staging release を作ります。
release source はTerraformで作成したCloud Deploy用bucketの`source/<app>`へ
アップロードされます。GitHub SAのStorage権限はこのbucketだけに限定しています。

## production へ昇格

GitHub Actions の **Promote to production** を Run workflow し、
staging release の GitHub Actions run ID を入力します。staging workflow が保存した
release 一覧を読み取り、対象 service を並列で production へ promote します。
production target は `require_approval = true` なので、続けて Google Cloud console
または次のコマンドで rollout を承認します。

```bash
gcloud deploy rollouts approve ROLLOUT \
  --delivery-pipeline=PIPELINE \
  --release=RELEASE \
  --region=asia-northeast1 \
  --project=orange-sandbox
```

## service を追加する

1. `apps/<app>/skaffold.yaml` と `apps/<app>/service.yaml` を追加する
2. `terraform/terraform.tfvars` の `services` に `<app>` を追加する
3. Terraform を apply する

`apps/<app>/**` の変更は自動検出されます。共通デプロイコード
（`scripts/**`、`.github/workflows/release.yml`）の変更時は全 service が対象です。

## コンテナ image について

初期 manifest は Artifact Registry 不要の公開 Cloud Run hello image を使っています。
`hello-function` には実際の function source と Dockerfile も含めています。実運用時は
CI で image を build/push し、`gcloud deploy releases create` の
`--images=APP_IMAGE=...@sha256:...` で digest を渡してください。
