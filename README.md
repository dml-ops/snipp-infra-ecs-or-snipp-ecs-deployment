# Snipp: A URL Shortener (3-tier web app) on AWS EC2

Snipp is a small URL shortener that I deployed on a single AWS EC2 instance as a hands on way to learn cloud and DevOps. You paste in a long link, you get a short one back, and visiting the short link sends you to the original page.

The app itself is simple on purpose. The real focus of this project is everything around it: infrastructure written as code with Terraform, containers managed with Docker Compose, automatic HTTPS with Caddy, and a GitHub Actions pipeline that builds, ships and deploys the app every time code is pushed to `main`.

If you would like the full story, including the errors I ran into and how I fixed them, there is a beginner friendly walkthrough on Hashnode:

**[How I Deployed a URL Shortener on AWS EC2 with Terraform, Docker Compose, Caddy and GitHub Actions](https://dmlops.hashnode.dev/how-i-deployed-a-url-shortener-on-aws-ec2-with-terraform-docker-compose-caddy-and-github-actions)**

![Snipp running on a custom domain with HTTPS](new-project/project-images/sn1.png)

---

## How It Fits Together

Here is the flow in plain words.

**1.** Your source code and Dockerfiles live in the `url-shortener` folder.
**2.** GitHub Actions reads the Dockerfiles and builds Docker images.
**3.** Amazon ECR stores those images.
**4.** Your EC2 server pulls the images from ECR and runs the app.
**5.** Caddy sits in front, serves the frontend, forwards API calls to the backend, and handles HTTPS.
**6.** The backend talks to a private PostgreSQL database on Amazon RDS.

Only ports 22, 80 and 443 are open to the internet. The backend never gets a public port, and the database only accepts traffic from the app server's security group.

![Architecture diagram showing GitHub Actions, ECR, EC2 with Caddy and the backend, and a private RDS database](new-project/project-images/sn2.png)

---

## Technologies Used

| Area | Tool |
|---|---|
| Cloud provider | AWS (EC2, VPC, RDS, ECR, Route 53, CloudWatch, SNS, IAM) |
| Infrastructure as code | Terraform with the AWS provider version 5 |
| Containers | Docker and Docker Compose |
| Reverse proxy and HTTPS | Caddy 2 with Let's Encrypt |
| Backend | Node.js 20 (Express) |
| Frontend | Node.js 20 build, served as static files |
| Database | PostgreSQL 16 (local container for development, RDS in production) |
| CI/CD | GitHub Actions |
| Server OS | Ubuntu 22.04 on a `t3.small` instance |
| Monitoring | CloudWatch agent with CPU and disk alarms through SNS |

---

## Project Structure

The project is split into two folders. One holds the application, the other holds the infrastructure.

![Project Structure diagram showing Application and Infastructure project component](new-project/project-images/sn3.png)

---

## Main Features

**Short links that redirect.** Paste a long URL and Snipp returns a short code. Codes between 4 and 10 letters, numbers, dashes or underscores are routed straight to the backend for lookup and redirect.

**One command local setup.** Docker Compose starts a local Postgres database, the backend, the frontend build and Caddy together, so you can test everything on your own machine first.

**Infrastructure as code.** One `terraform apply` creates the whole environment: a VPC with public and private subnets, security groups, an Elastic IP, an EC2 server, a private RDS database, DNS records and monitoring.

**Automatic HTTPS.** Caddy requests and renews a Let's Encrypt certificate on its own. There is no Certbot and no cron job to remember.

**Private by design.** The database is not publicly accessible and trusts only the web server's security group. The backend is reachable only through Caddy over the Docker network.

**Automated deployments.** Every push to `main` builds the backend and frontend images, pushes them to ECR, copies the compose files to the server, logs in to ECR fresh, pulls the new images and restarts the stack.

**Built in health check.** The pipeline ends by calling `/api/health` on the server. A healthy app answers with `{"status":"ok","db":"connected"}`.

**Basic monitoring.** The CloudWatch agent reports memory, disk and CPU usage, and alarms notify you through an SNS topic when CPU passes 80 percent or disk usage passes 85 percent.

---

## Prerequisites

Before you start, make sure you have these ready.

1. An AWS account with the AWS CLI configured (`aws sts get-caller-identity` should work)
2. Terraform installed (`terraform -version`)
3. Docker Desktop, running
4. Git and a terminal such as Git Bash
5. A GitHub account
6. A domain name from any registrar

---

## Setup Instructions

### 1. Run it locally first

It is always easier to fix problems on your own machine than on a server.

```bash
cd url-shortener
docker compose --env-file .env.local up -d --build
docker compose ps
curl http://localhost/api/health
```

Your `.env.local` should look like this:

```
POSTGRES_DB=shortener
POSTGRES_USER=app_admin
POSTGRES_PASSWORD=devpassword
DATABASE_URL=postgresql://app_admin:devpassword@postgres:5432/shortener
APP_BASE_URL=
DOMAIN=localhost
```

Open `https://localhost` in your browser and accept the local certificate warning. You should see the Snipp homepage.

![Snipp running locally at https://localhost](new-project/project-images/sn5.png)

### 2. Create an SSH key

Terraform uploads the public half of this key so you can log in to the server.

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/urlshortener_key
```

### 3. Provision the infrastructure

In the `urlshortener-infra` folder, create a `terraform.tfvars` file with your own values:

```hcl
db_password = "YourPasswordHere"
domain_name = "yourdomain.com"
```

Use only letters and numbers in the password. Special characters can break connection strings later.

Then run:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
```

Save the four values it prints: the server IP, the database endpoint, the SSH command and the name servers.

![Terraform outputs showing the server IP, database endpoint, SSH command and name servers](new-project/project-images/sn4.png)

### 4. Point your domain at AWS

At your domain registrar, switch from the default name servers to custom DNS and enter all four Route 53 name servers from the Terraform output. DNS will propagate in the background while you continue.

![Registrar settings with the four AWS Route 53 name servers entered as custom DNS](new-project/project-images/sn6.png)

### 5. Prepare the server

SSH into the new instance and install Docker, Docker Compose, the AWS CLI and the CloudWatch agent, then create the `~/app` folder where the pipeline will place the compose files. The exact commands are in the Hashnode walkthrough, in the section called "Prepare the server".

### 6. Create the ECR repositories

```bash
aws ecr create-repository --repository-name urlshortener-backend --region eu-north-1
aws ecr create-repository --repository-name urlshortener-frontend --region eu-north-1
```

Keep the registry part of the returned URI, which is everything before the repository name. You need it for the next step.

### 7. Add your GitHub secrets

In your repository, open **Settings**, then **Secrets and variables**, then **Actions**, and add the following.

| Secret | What it holds |
|---|---|
| `EC2_HOST` | The Elastic IP from the Terraform output |
| `EC2_SSH_KEY` | The full contents of your private key `~/.ssh/urlshortener_key` |
| `AWS_ACCESS_KEY_ID` | Access key for a CI user with ECR push permissions |
| `AWS_SECRET_ACCESS_KEY` | The matching secret key |
| `AWS_REGION` | `eu-north-1` |
| `ECR_REGISTRY` | Your registry, for example `123456789012.dkr.ecr.eu-north-1.amazonaws.com` |
| `DATABASE_URL` | `postgresql://app_admin:PASSWORD@DB_HOST:5432/shortener?uselibpqcompat=true&sslmode=require` |
| `DOMAIN` | `yourdomain.com` |
| `APP_BASE_URL` | `https://yourdomain.com` |

A couple of things worth knowing. The `?uselibpqcompat=true&sslmode=require` ending on `DATABASE_URL` is important because RDS refuses unencrypted connections. And for anything beyond learning, use a dedicated IAM user with only the ECR permissions it needs, not your main account keys.

### 8. Give the server permission to pull from ECR

The EC2 instance logs in to ECR using its IAM role. Make sure `main.tf` includes this attachment, then run `terraform apply`:

```hcl
resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```

Without it, every image pull on the server fails with "no basic auth credentials".

---

## Workflow Usage Guide

### Deploying a change

1. Make your code change locally and test it with Docker Compose.
2. Commit and push to the `main` branch.
3. Open the **Actions** tab in GitHub and watch the pipeline run.
4. When the last step, the health check, goes green, your change is live.

You can also run the pipeline by hand from the Actions tab, because the workflow supports manual dispatch.

![GitHub Actions run with the build and push job and the deploy job both passing](new-project/project-images/sn7.png)

### Checking that everything works

```bash
curl -i https://yourdomain.com/api/health
```

A response of `HTTP/1.1 200` with `{"status":"ok","db":"connected"}` means the app and the database are both healthy. Then open your domain, shorten a long URL, and paste the short link into a new tab to confirm it redirects.

![A long URL being shortened in Snipp and the short link redirecting to the original page](new-project/project-images/sn8.png)

### Looking at logs

```bash
ssh -i ~/.ssh/urlshortener_key ubuntu@YOUR_SERVER_IP
cd /home/ubuntu/app
docker compose logs --tail=50 backend
docker compose logs caddy
```

### Turning on alerts

After the first `terraform apply`, subscribe your email to the `urlshortener-alerts` SNS topic from the AWS console and confirm the link AWS sends you. Terraform can create the topic, but it cannot click that confirmation link for you.

---

## Troubleshooting

These are the real problems I hit while building this, in case you meet them too.

**The build and push step fails.** Check your `ECR_REGISTRY` secret. It should be the account ID plus `.dkr.ecr.eu-north-1.amazonaws.com`, with no repository name on the end.

**The server cannot pull images ("no basic auth credentials").** The server's IAM role is missing ECR read access. Add the policy attachment from step 8.

**The site shows a 502 error.** Caddy is fine, but the backend is crashing. Run `docker compose logs --tail=50 backend` on the server. If you see `no pg_hba.conf entry` or `self signed certificate in certificate chain`, add `?uselibpqcompat=true&sslmode=require` to the end of `DATABASE_URL`, and update the GitHub secret too so the next deploy does not overwrite your fix.

![A 502 Bad Gateway response from curl, caused by the backend failing to connect to RDS](docs/images/502-error.png)

**Docker says "no configuration file provided".** You are probably in the wrong folder. Make sure `docker-compose.yml`, `.env.local`, `backend`, `caddy` and `frontend` all sit together in one project folder.

**A redeploy fails at docker login.** ECR login tokens expire after twelve hours. The workflow already logs in fresh on every deploy, so keep that step in place.

**The certificate does not arrive.** Check that your name servers have finished propagating and that ports 80 and 443 are reachable, then look at `docker compose logs caddy`.

---

## Security Notes

Please keep these in mind before sharing or reusing this project.

**Never commit secrets.** `terraform.tfvars`, `.env`, `.env.local`, state files and private keys must stay out of Git.

**Restrict SSH.** The default `allowed_ssh_cidr` is open to the whole internet, which is fine for learning. For anything real, set it to your own IP address, for example `203.0.113.10/32`.

**Rotate anything exposed.** If an access key, password or private key ever appears in a screenshot, a document or a chat, deactivate it and create a new one.

---

## What I Would Improve Next

Tighter IAM permissions for the CI user, image tags based on the commit instead of only `latest`, a remote Terraform state backend, and a more production ready setup with a load balancer and backups.

---

## Learn More

The full walkthrough, with every command and every screenshot, is on Hashnode:

[https://dmlops.hashnode.dev/how-i-deployed-a-url-shortener-on-aws-ec2-with-terraform-docker-compose-caddy-and-github-actions]

