# Cloud Build builders

このディレクトリには、appのソースからコンテナimageを作るCloud Build設定を置きます。
`scripts/select-build-config.sh`が`apps/<app>`内のファイルを調べ、使用する設定を
選択します。

## builder YAMLの要件

新しいbuilder YAMLは、次の契約を満たす必要があります。

- build contextは`apps/<app>`であり、リポジトリルートには依存しない
- user-defined substitutionsとして`_IMAGE`と`_TAG`を受け取る
- 最終imageを`${_IMAGE}:${_TAG}`としてArtifact Registryへpushする
- `images`に`${_IMAGE}:${_TAG}`を指定し、Cloud Buildのbuild結果へimageとdigestを
  記録する
- `options.requestedVerifyOption: VERIFIED`を指定し、Binary Authorizationの
  `built-by-cloud-build` attestationを生成する
- `options.logging: CLOUD_LOGGING_ONLY`を指定する
- appのソース以外の秘密情報やGitHub Actions上の認証情報に依存しない

workflowはbuild完了後に`${_IMAGE}:${_TAG}`のdigestをArtifact Registryから取得し、
digest固定のimage参照をCloud Deployへ渡します。`images`の指定がない、または実際に
pushした参照と一致しない場合、buildやBinary Authorizationの検証が失敗します。

`ko`はOCI imageを直接pushするとCloud Buildの`images`収集で認識されないため、
一度Cloud BuildのDocker daemonへロードし、Docker builderからpushしています。

builderを追加するときは、次も更新してください。

1. `scripts/select-build-config.sh`へ判定条件を追加する
2. `scripts/select-build-config.test.sh`へ正常系と競合時のテストを追加する
3. 実際に`gcloud builds submit`を実行し、build結果の
   `options.requestedVerifyOption`が`VERIFIED`、`results.images`が期待するimageに
   なっていることを確認する

## 権限

buildの呼び出し元と実行主体には別のservice accountを使います。

### GitHub Actions service account

`github-cloud-deploy@<deploy_project_id>.iam.gserviceaccount.com`はbuildを起動する
主体です。
buildに関係する権限は次のとおりです。

- projectの`roles/cloudbuild.builds.editor`: buildの作成と参照
- projectの`roles/serviceusage.serviceUsageConsumer`: API利用
- Cloud Build builder service accountに対する`roles/iam.serviceAccountUser`:
  build実行時のservice account指定
- Cloud Deploy bucketの`roles/storage.admin`: build source archiveのuploadと
  Cloud Deploy release sourceの管理
- Artifact Registry repositoryの`roles/artifactregistry.reader`: build後のdigest取得
- projectの`roles/containeranalysis.occurrences.viewer`: provenanceを含むimage情報の参照

### Cloud Build builder service account

`cloud-build-builder@<deploy_project_id>.iam.gserviceaccount.com`がbuilder YAMLの
stepを実行します。利用できる権限は次の範囲に限定しています。

- Artifact Registry repositoryの`roles/artifactregistry.writer`: imageのpush
- Cloud Deploy bucketの`roles/storage.objectViewer`: build source archiveの取得
- projectの`roles/logging.logWriter`: build logのCloud Loggingへの書き込み

このservice accountにはCloud DeployやCloud Runを操作する権限、GitHubへアクセス
する権限、Cloud Deploy bucketへ書き込む権限はありません。

権限定義は`terraform/iam.tf`、`terraform/storage.tf`、
`terraform/artifact_registry.tf`にあります。
