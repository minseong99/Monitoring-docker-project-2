# 🐳 Docker Monitoring Architecture (Nginx + Prometheus + Grafana)


## 概要

このプロジェクトは、単一のホストサーバー（EC2等を想定）上において、Dockerコンテナベースのセキュアで自動化された監視アーキテクチャを構築するプロジェクトです。
単なるDocker環境の構築にとどまらず、**GitHub ActionsとAWS Systems Manager (SSM) を用いた「完全自動・SSHレス」なセキュアデプロイパイプライン**を実装しています。

> **Infrastructure Repository :** [https://github.com/minseong99/aws-with-terraform-project-1]
> 本アプリケーションが稼働するAWSインフラ（VPC, ALB, Private EC2など）のTerraformコードは上記リポジトリで管理し、関心の分離を実現しています。

## プロジェクトの目的とハイライト

- **コンテナ・オーケストレーションの基礎:** `docker-compose` を用いた複数コンテナの連携と内部ネットワーク（Bridge）の構築。
- **リバースプロキシとセキュリティ強化:** ユーザーからのアクセス（80番ポート）を `Nginx` で受け止め、内部ネットワークに隠蔽された `Grafana`（3000番ポート）へ安全にルーティング。
- **Pull型モニタリングアーキテクチャ:** `Prometheus` を中心とし、ホストOSのメトリクスを `Node Exporter`、コンテナのメトリクスを `cAdvisor` から定期的に収集。
- **ダッシュボードの完全プロビジョニング (IaC):** `Grafana` のGUI上での手動設定を廃止。データソースの接続とJSONダッシュボードの生成をコンテナ起動時に全自動化。
- **SSH不要のセキュアな自動デプロイ:** AWS SSM Run Commandを活用することで、Private Subnet内のEC2に対して、22番ポートを一切開けずにGitHub Actionsから直接安全にデプロイを実行します。

## 🔄 CI/CD パイプラインによる自動デプロイフロー

`main` ブランチにコードがPushされると、以下のワークフローが全自動で実行されます。

1. **OIDC認証:** GitHub ActionsがOpenID Connect経由でAWSの一時的なクレデンシャルを安全に取得（アクセスキーのハードコード排除）。
2. **EC2インスタンスの特定:** AWS CLIでタグ名から現在稼働中のターゲットEC2（ASG管理下）を動的に検索。
3. **SSM Run Commandの送信:** EC2内部のSSM Agentに対し、シェルスクリプトを送信。
4. **EC2内部での処理 (Pull & Deploy):**
   - リポジトリの `git clone` または最新コードの `git pull`
   - `docker compose up -d -build` によるコンテナの再起動・最新化

---

## アーキテクチャ構成

| サービス名 | 役割 | 使用ポート (外部:内部) |
| :--- | :--- | :--- |
| **Nginx** | リバースプロキシ (ALBからのトラフィック受信) | `80:80` |
| **Grafana** | データの可視化・ダッシュボード | `公開なし:3000` |
| **Prometheus** | メトリクスの収集・蓄積（時系列DB） | `公開なし:9090` |
| **Node Exporter** | ホストOS（Linux）のメトリクス収集 | `公開なし:9100` |
| **cAdvisor** | Dockerコンテナのメトリクス収集 | `公開なし:8080` |

> **Security Note:** Nginx以外のコンテナはホスト側へポートを公開せず、Dockerの内部ネットワーク(`monitoring-network`)でのみ通信を行うセキュアな設計にしています。

## 📁 ディレクトリ構造

```text
.
├── .github/                    
│   └── workflows/
        ├── deploy.yml           # CI/CD
├── bootstrap/                    
│   └── .terraform.lock.hcl
│   └── oidc.tf                  # CI/CDに使うOIDC IAM Role
├── .env.example                 # 環境変数のテンプレート
├── docker-compose.yml           # コンテナ全体の設計図
├── nginx/
│   └── conf.d/
│       └── default.conf         # Nginxのリバースプロキシ設定
├── prometheus/
│   └── prometheus.yml           # Prometheusのスクレイプ（収集）設定
└── grafana/
    └── provisioning/
        ├── dashboards/
        │   ├── dashboard.yml    # ダッシュボード自動読み込み設定
        │   └── node-exporter.json # ダッシュボードのJSON設計図
        └── datasources/
            └── datasource.yml   # Prometheusデータソースの自動登録設定
```

## 起動方法(How to run in local)

**1. gitでダウンロード**

このシステムをロカルで利用するためダウンロードをしてください。
```bash
git clone "https://github.com/minseong99/Monitoring-docker-project-2.git"
```

**2.環境変数の設定** 

grafanaのID/PASSWORDの環境変数を設定してください。
```bash
cd Monitoring-docker-project-2
cp .env.exaple .env
```

**3.コンテナ生成およびアクセス**

まず`docker-compose`を使ってbackgroundでimageをダウンロードと同時にコンテナの生成および起動してください。
```bash
docker-compose up -d
```

そして`http://localhost`にアクセスを確認してください。
> **ダッシュボード確認** 環境変数と設定したID/Passwordを使ってログインしてダッシュボードタップをクリックすると自動生成されたグラフを確認してまらえます。

**💡local environment Note:**

本プロジェクトの nginx/conf.d/default.conf は、AWS ALB環境下（本番）での稼働に最適化されています（Sticky SessionやX-Forwarded-Forの処理等）。
もしローカル環境（localhost）での検証時にログインループ等が発生する場合は、同ファイル内の X-Real-IP や X-Forwarded-For の設定行を一時的にコメントアウトして起動してください。


## クリーンアップ
このシステムを使わない場合コンテナを削除できます。

```bash
docker-compose down
```
もし以前のデータも削除したい場合はvolumeまで削除できます。
```bash
docker-compose down -v
```
