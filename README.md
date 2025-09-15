# Deploying a Static React SPA to AWS with CloudFront and GitHub Actions

This project demonstrates two ways to deploy the contents of a build directory to Amazon Web Services (AWS) using S3 for storage, CloudFront as a content delivery network (CDN), and GitHub Actions for continuous integration and deployment (CI/CD).

Choose your preferred deployment method:

[Manual Deployment](#manual-deployment) | [Terraform Deployment](#terraform-deployment)

---

## Manual Deployment

How to setup the entire infrastructure manually using the AWS Management Console.

### 1. Prerequisites

*   A GitHub account and a repository with your React application.
*   Node.js and npm (or yarn) installed on your local machine to build the React app.

### 2. Create a New AWS Account

If you don't already have an AWS account, you'll need to create one. AWS offers a Free Tier that provides a limited amount of services for free for 12 months, and some services have an always-free tier.

1.  **Go to the AWS Free Tier page:** [https://aws.amazon.com/free/](https://aws.amazon.com/free/)
2.  **Click "Create a Free Account".**
3.  **Enter your account information:** You will need to provide an email address, a password, and an AWS account name.
4.  **Provide your contact information:** This includes your name, address, and phone number.
5.  **Enter your billing information:** You will need to provide a credit/debit card. AWS uses this to verify your identity and for any usage that exceeds the free tier limits. You won't be charged unless your usage goes beyond the free tier.
6.  **Confirm your identity:** You'll receive a phone call or text message with a verification code.
7.  **Choose a Support Plan:** Select the "Basic Support - Free" plan.
8.  **Complete the sign-up.**

Once your account is created, you will have access to the AWS Management Console. It may take a few minutes to a few hours for your account to be fully activated.

### 3. Set up S3 for Static Website Hosting

Amazon S3 (Simple Storage Service) is where we will store the built files of our React application.

#### 3.1. Create an S3 Bucket

1.  **Open the S3 service:** In the AWS Management Console, search for "S3" in the services search bar and select it.
2.  **Create a new bucket:** Click on the "Create bucket" button.
3.  **Configure the bucket:**
    *   **Bucket name:** Choose a globally unique name for your bucket (e.g., `your-app-name-prod-static`).
    *   **AWS Region:** Select a region that is geographically close to your target audience.
4.  **Block Public Access settings:** Leave the "Block all public access" settings **checked** (the default). We will provide access to the bucket only from CloudFront.
5.  **Create the bucket:** Leave the rest of the settings as default and click "Create bucket".

#### 3.2. Enable Static Website Hosting

Even though we will be serving content through CloudFront, it's a good practice to configure the bucket for static website hosting, mainly to set the index and error documents.

1.  **Select your bucket:** From the S3 buckets list, click on the name of the bucket you just created.
2.  **Go to Properties:** Click on the "Properties" tab.
3.  **Enable Static website hosting:** Scroll down to the "Static website hosting" section and click "Edit".
    *   Select **"Enable"**.
    *   In **"Index document"**, enter `index.html`.
    *   In **"Error document"**, enter `index.html`. This is important for a React SPA to handle client-side routing.
    *   Click **"Save changes"**.

Your S3 bucket is now created. We will add the bucket policy that allows CloudFront to access it in the next step.

### 4. Set up a CloudFront Distribution

CloudFront is a CDN that will cache our application's content at edge locations around the world. The setup process has recently been highly simplified by AWS.

#### 4.1. Create the Distribution

1.  **Navigate to Distributions:** In the AWS Console, go to the CloudFront service. In the left menu, click **Distributions**, and then **"Create distribution"**.
2.  **Configure Origin:**
    *   **Origin domain:** Choose your S3 bucket from the dropdown list.
    *   **Allow private S3 bucket access to CloudFront:** This is the most important section for securing your bucket. The UI should have a section with this exact title.
    *   **Action Required: None.** The default setting, labeled **"Allow private S3 bucket access to CloudFront - Recommended"**, handles the entire security configuration automatically. As the AWS info panel states, CloudFront will create the necessary access controls (the OAC) and update your S3 bucket policy for you when the distribution is created. You do not need to manually create an OAC or copy any policies.

#### 4.2. Configure Viewer and Cache Settings

1.  **Viewer protocol policy:** Set this to **"Redirect HTTP to HTTPS"** to ensure all traffic is secure.
2.  **Allowed HTTP methods:** Select **"GET, HEAD, OPTIONS"**.
3.  **Cache key and origin requests:** For the cache policy, you can use the default **`CachingOptimized`**.

#### 4.3. Web Application Firewall (WAF)

On the final page of the wizard, you will be asked to configure security.

1.  **Web Application Firewall (WAF):** You must select one of the two options.
    *   Select **"Do not enable security protections"**.
    *   **Reasoning:** AWS WAF is a powerful security service, but it is not part of the Free Tier. Enabling it will incur costs. For this tutorial, we will not use it.

#### 4.4. Create the Distribution and Configure SPA Settings

1.  Click **"Create distribution"**.
2.  **Wait for deployment:** It will take several minutes for the distribution to deploy. You can see its status in the CloudFront console. Wait until the "Last modified" date is no longer "Deploying".
3.  **Configure Post-Creation Settings:** Once the distribution is deployed, click on its ID to open its configuration page. We now need to set the final options to make it work with a React SPA.
    *   **Set the Default Root Object:**
        *   Navigate to the **"General"** tab and click **"Edit"**.
        *   In the **"Default root object"** field, enter `index.html`.
        *   Click **"Save changes"**.
    *   **Create Custom Error Responses:** This is crucial for React Router.
        *   Navigate to the **"Error pages"** tab.
        *   Click **"Create custom error response"**.
        *   **HTTP error code:** Select **"403: Forbidden"**.
        *   **Customize error response:** Select **"Yes"**.
        *   **Response page path:** Enter `/index.html`.
        *   **HTTP Response code:** Select **"200: OK"**.
        *   Click **"Create custom error response"**.
        *   Repeat this exact process for **"404: Not Found"**, also mapping it to `/index.html` with a **"200: OK"** response.

Once these changes are saved, you can use the **Distribution domain name** to access your application.

### 5. Set up GitHub Actions for CI/CD

Now we'll set up a GitHub Actions workflow to automatically build our React app, deploy it to S3, and invalidate the CloudFront cache whenever we push changes to our repository.

#### 5.1. Create an IAM User for GitHub Actions

For security, we'll create a dedicated IAM (Identity and Access Management) user for GitHub Actions with only the permissions it needs.

1.  **Open the IAM service** in the AWS Management Console.
2.  **Go to "Users"** and click **"Create user"**.
3.  **User name:** Give it a descriptive name like `github-actions-deployer`.
4.  **Permissions options:** Choose **"Attach policies directly"**.
5.  **Create a new policy:** Click on **"Create policy"**. This will open a new tab.
    *   In the policy editor, switch to the **JSON** tab.
    *   Paste the following policy. Remember to replace `your-bucket-name` with your actual S3 bucket name.

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowS3Sync",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::your-bucket-name",
                    "arn:aws:s3:::your-bucket-name/*"
                ]
            },
            {
                "Sid": "AllowCloudFrontInvalidation",
                "Effect": "Allow",
                "Action": "cloudfront:CreateInvalidation",
                "Resource": "*"
            }
        ]
    }
    ```
    *   Click **"Next: Tags"**, then **"Next: Review"**.
    *   Give the policy a name like `GitHubActions-S3-CloudFront-Deploy-Policy`.
    *   Click **"Create policy"**.
6.  **Attach the policy:** Go back to the user creation tab, refresh the list of policies, and select the policy you just created. Click **"Next"**.
7.  **Create the user:** Review the details and click **"Create user"**.
8.  **Get security credentials:**
    *   Click on the user you just created.
    *   Go to the **"Security credentials"** tab.
    *   Under **"Access keys"**, click **"Create access key"**.
    *   Select **"Third-party service"** as the use case, acknowledge the recommendation, and click **"Next"**.
    *   Click **"Create access key"**.
    *   **This is your only chance to see the Secret Access Key.** Copy both the **Access key ID** and the **Secret access key** and save them somewhere safe temporarily.

#### 5.2. Add AWS Credentials to GitHub Secrets

1.  In your GitHub repository, go to **"Settings"** > **"Secrets and variables"** > **"Actions"**.
2.  Click **"New repository secret"** for each of the following secrets:
    *   `AWS_ACCESS_KEY_ID`: The Access Key ID you just created.
    *   `AWS_SECRET_ACCESS_KEY`: The Secret Access Key.
    *   `AWS_REGION`: The AWS region of your S3 bucket (e.g., `us-east-1`).
    *   `S3_BUCKET_NAME`: The name of your S3 bucket.
    *   `CLOUDFRONT_DISTRIBUTION_ID`: Go to your CloudFront distribution to find its ID (it's a string like `E1234567890ABC`).

#### 5.3. Create the GitHub Actions Workflow

This workflow will run on every push to the `main` branch. It will build the React app, sync the build files to S3, and create a CloudFront invalidation.

1.  In your project, create a directory `.github/workflows`.
2.  Inside this directory, create a file named `deploy.yml`. The next section will provide the content for this file.

---

## Terraform Deployment

How to use Terraform to setup all of the AWS infrastructure. The Terraform configuration is located in the `tf/` directory. This is the recommended approach for managing your infrastructure as code.

### 1. Prerequisites

*   The [AWS CLI](https://aws.amazon.com/cli/) installed on your local machine.
*   [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) installed on your local machine.

### 2. Local AWS Configuration (One-Time Setup)

To allow Terraform to securely access your AWS account, you must configure the AWS CLI. This requires an IAM User with permissions to manage the Terraform state backend. **This user is for your local development machine and is separate from the IAM Role that the GitHub Actions CI/CD pipeline will use.**

Each developer on the team should have their own IAM user to ensure accountability and security.

1.  **Create a `<developer-name>-developer` IAM User:**
    *   In the AWS Console, navigate to **IAM** > **Users** and create a new user named `<your-name>-developer` (e.g., `jane-doe-developer`).
    *   On the permissions screen, choose **"Attach policies directly"**, then click **"Create policy"**.
    *   In the policy editor, switch to the **JSON** tab and paste the policy below. **Important:** Replace `your-terraform-state-bucket-name` with the actual name of the S3 bucket you created for your Terraform state.

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "TerraformStateBucketRead",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::your-terraform-state-bucket-name"
            },
            {
                "Sid": "TerraformStateObjectActions",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject"
                ],
                "Resource": "arn:aws:s3:::your-terraform-state-bucket-name/*"
            },
            {
                "Sid": "ProjectS3BucketManagement",
                "Effect": "Allow",
                "Action": [
                    "s3:CreateBucket",
                    "s3:DeleteBucket",
                    "s3:ListAllMyBuckets",
                    "s3:GetBucketLocation",
                    "s3:GetBucketPolicy",
                    "s3:PutBucketPolicy",
                    "s3:PutBucketPublicAccessBlock",
                    "s3:PutBucketWebsite"
                ],
                "Resource": "*"
            },
            {
                "Sid": "ProjectIAMManagement",
                "Effect": "Allow",
                "Action": [
                    "iam:GetOpenIDConnectProvider",
                    "iam:ListOpenIDConnectProviders",
                    "iam:CreateRole",
                    "iam:DeleteRole",
                    "iam:GetRole",
                    "iam:TagRole",
                    "iam:ListRolePolicies",
                    "iam:ListAttachedRolePolicies",
                    "iam:CreatePolicy",
                    "iam:DeletePolicy",
                    "iam:GetPolicy",
                    "iam:AttachRolePolicy",
                    "iam:DetachRolePolicy"
                ],
                "Resource": "*"
            },
            {
                "Sid": "ProjectCloudFrontManagement",
                "Effect": "Allow",
                "Action": [
                    "cloudfront:CreateDistribution",
                    "cloudfront:GetDistribution",
                    "cloudfront:UpdateDistribution",
                    "cloudfront:DeleteDistribution",
                    "cloudfront:CreateOriginAccessControl",
                    "cloudfront:GetOriginAccessControl",
                    "cloudfront:DeleteOriginAccessControl"
                ],
                "Resource": "*"
            }
        ]
    }
    ```
    *   Name the policy `TerraformDeveloperPermissions` and create it.
    *   Back on the user creation tab, attach the new policy to your `<your-name>-developer` user and finish creating it.

2.  **Create an Access Key for the CLI:**
    *   Navigate to your new `<your-name>-developer` user's summary page.
    *   Go to the **"Security credentials"** tab and click **"Create access key"**.
    *   Choose **"Command Line Interface (CLI)"** as the use case and create the key.
    *   Copy the **Access Key ID** and **Secret Access Key**.

3.  **Configure the AWS CLI:**
    *   In your terminal, run the `aws configure` command and provide the credentials you just created.
    ```bash
    aws configure
    ```
    *   **AWS Access Key ID:** Enter the Access Key ID for your `<your-name>-developer` user.
    *   **AWS Secret Access Key:** Enter the Secret Access Key.
    *   **Default region name:** Enter your preferred AWS region (e.g., `us-east-1`).
    *   **Default output format:** You can leave this blank.

The AWS CLI now has credentials for a user who can properly manage the remote state backend.

### 3. Create the GitHub Actions OIDC Provider (One-Time Setup)

Before you can deploy the Terraform code, you must establish a trust relationship between your AWS account and GitHub Actions. This is a one-time setup for your entire AWS account.

1.  **Navigate to IAM > Identity Providers** in the AWS Management Console.
2.  Click **"Add provider"**.
3.  Select **"OpenID Connect"**.
4.  For **Provider URL**, enter `https://token.actions.githubusercontent.com`.
5.  For **Audience**, enter `sts.amazonaws.com`.
6.  Click **"Add provider"**.

Your AWS account is now configured to trust GitHub Actions.

### 4. Manual Setup for Terraform Backend

Before you can use Terraform to manage your infrastructure, you need a place to store its state file. This is a one-time manual setup.

1.  **Create an S3 Bucket for Terraform State:**
    *   Go to the S3 service in the AWS Management Console.
    *   Create a new, private S3 bucket with a globally unique name (e.g., `your-company-terraform`).
    *   **Enable bucket versioning.** This is critical as it acts as a built-in backup and recovery system for your state file, protecting you from accidental deletions or state corruption.

    *That's it. With modern versions of Terraform, a separate DynamoDB table for state locking is no longer required.*

### 5. Configure and Deploy the Infrastructure

1.  **Navigate to the Terraform directory:**
    ```bash
    cd tf
    ```

2.  **Update the backend configuration:**
    *   Open the `main.tf` file.
    *   Replace `"your-terraform-state-bucket-name"` with the name of the S3 bucket you created for the backend state.

3.  **Initialize Terraform:** This only needs to be done once.
    ```bash
    terraform init
    ```

4.  **Create your Development Workspace:** Terraform workspaces allow you to manage multiple environments. We'll start with `dev`.
    ```bash
    terraform workspace new dev
    ```
    *This command creates a new workspace called `dev` and automatically switches to it. You can see available workspaces with `terraform workspace list`.*

5.  **Review and Apply the Plan for Dev:** Now you can deploy the `dev` environment using its specific variable file.
    ```bash
    # See what changes Terraform will make
    terraform plan -var-file="dev.tfvars"

    # Apply the changes
    terraform apply -var-file="dev.tfvars"
    ```
    Terraform will show you a plan of the resources it will create. Type `yes` to approve the plan. Your infrastructure is now deployed for the `dev` environment.

### 6. Managing a Production Environment

When you are ready to deploy to production, the process is very similar.

1.  **Create a `prod.tfvars` file:**
    *   Make a copy of `dev.tfvars` and name it `prod.tfvars`.
    *   Change the values inside `prod.tfvars` to what you need for your production environment (e.g., you might change the `deploy_bucket_name`).

2.  **Create and switch to the `prod` workspace:**
    ```bash
    terraform workspace new prod
    ```

3.  **Deploy to Production:** Apply the configuration using the `prod.tfvars` file.
    ```bash
    terraform plan -var-file="prod.tfvars"
    terraform apply -var-file="prod.tfvars"
    ```

You now have two completely separate sets of infrastructure deployed for `dev` and `prod`, with their state files safely isolated in your S3 bucket. You can switch between them at any time using `terraform workspace select <name>`.

### 7. Update GitHub Actions Workflow

After you have successfully run `terraform apply`, you need to update your GitHub Actions workflow to use the new IAM role.

1.  **Get the IAM Role ARN:**
    *   Run `terraform output github_actions_iam_role_arn` to get the ARN of the created IAM role.

2.  **Get the CloudFront Distribution ID:**
    *   Run `terraform output cloudfront_distribution_id` to get the ID of the CloudFront distribution.

3.  **Update GitHub Secrets:**
    *   Go to your GitHub repository's **Settings > Secrets and variables > Actions**.
    *   You no longer need `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. You can delete them.
    *   Add a new secret `AWS_ROLE_TO_ASSUME` and set its value to the IAM role ARN you retrieved.
    *   Update the `CLOUDFRONT_DISTRIBUTION_ID` secret with the new ID from the Terraform output.

4.  **Update the `deploy.yml` workflow:**
    *   Modify your workflow to use the `aws-actions/configure-aws-credentials` action with the IAM role. See the updated example in the next section.

Your CI/CD pipeline is now configured to securely deploy your application using the infrastructure managed by Terraform.
