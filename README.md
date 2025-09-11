# Deploying a Static React SPA to AWS with CloudFront and GitHub Actions

This tutorial will guide you through deploying a static React single-page application (SPA) to Amazon Web Services (AWS) using S3 for storage, CloudFront as a content delivery network (CDN), and GitHub Actions for continuous integration and deployment (CI/CD).

## Table of Contents

1.  [Prerequisites](#prerequisites)
2.  [Step 1: Create a New AWS Account](#step-1-create-a-new-aws-account)
3.  [Step 2: Set up S3 for Static Website Hosting](#step-2-set-up-s3-for-static-website-hosting)
4.  [Step 3: Set up a CloudFront Distribution](#step-3-set-up-a-cloudfront-distribution)
5.  [Step 4: Set up GitHub Actions for CI/CD](#step-4-set-up-github-actions-for-cicd)

## Prerequisites

*   A GitHub account and a repository with your React application.
*   Node.js and npm (or yarn) installed on your local machine to build the React app.

## Step 1: Create a New AWS Account

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

## Step 2: Set up S3 for Static Website Hosting

Amazon S3 (Simple Storage Service) is where we will store the built files of our React application.

### 2.1. Create an S3 Bucket

1.  **Open the S3 service:** In the AWS Management Console, search for "S3" in the services search bar and select it.
2.  **Create a new bucket:** Click on the "Create bucket" button.
3.  **Configure the bucket:**
    *   **Bucket name:** Choose a globally unique name for your bucket (e.g., `your-app-name-prod-static`).
    *   **AWS Region:** Select a region that is geographically close to your target audience.
4.  **Block Public Access settings:** Leave the "Block all public access" settings **checked** (the default). We will provide access to the bucket only from CloudFront.
5.  **Create the bucket:** Leave the rest of the settings as default and click "Create bucket".

### 2.2. Enable Static Website Hosting

Even though we will be serving content through CloudFront, it's a good practice to configure the bucket for static website hosting, mainly to set the index and error documents.

1.  **Select your bucket:** From the S3 buckets list, click on the name of the bucket you just created.
2.  **Go to Properties:** Click on the "Properties" tab.
3.  **Enable Static website hosting:** Scroll down to the "Static website hosting" section and click "Edit".
    *   Select **"Enable"**.
    *   In **"Index document"**, enter `index.html`.
    *   In **"Error document"**, enter `index.html`. This is important for a React SPA to handle client-side routing.
    *   Click **"Save changes"**.

Your S3 bucket is now created. We will add the bucket policy that allows CloudFront to access it in the next step.

## Step 3: Set up a CloudFront Distribution

CloudFront is a CDN that will cache our application's content at edge locations around the world. The setup process has recently been highly simplified by AWS.

### 3.1. Create the Distribution

1.  **Navigate to Distributions:** In the AWS Console, go to the CloudFront service. In the left menu, click **Distributions**, and then **"Create distribution"**.
2.  **Configure Origin:**
    *   **Origin domain:** Choose your S3 bucket from the dropdown list.
    *   **Allow private S3 bucket access to CloudFront:** This is the most important section for securing your bucket. The UI should have a section with this exact title.
    *   **Action Required: None.** The default setting, labeled **"Allow private S3 bucket access to CloudFront - Recommended"**, handles the entire security configuration automatically. As the AWS info panel states, CloudFront will create the necessary access controls (the OAC) and update your S3 bucket policy for you when the distribution is created. You do not need to manually create an OAC or copy any policies.

### 3.2. Configure Viewer and Cache Settings

1.  **Viewer protocol policy:** Set this to **"Redirect HTTP to HTTPS"** to ensure all traffic is secure.
2.  **Allowed HTTP methods:** Select **"GET, HEAD, OPTIONS"**.
3.  **Cache key and origin requests:** For the cache policy, you can use the default **`CachingOptimized`**.

### 3.3. Web Application Firewall (WAF)

On the final page of the wizard, you will be asked to configure security.

1.  **Web Application Firewall (WAF):** You must select one of the two options.
    *   Select **"Do not enable security protections"**.
    *   **Reasoning:** AWS WAF is a powerful security service, but it is not part of the Free Tier. Enabling it will incur costs. For this tutorial, we will not use it.

### 3.4. Create the Distribution and Configure SPA Settings

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

## Step 4: Set up GitHub Actions for CI/CD

Now we'll set up a GitHub Actions workflow to automatically build our React app, deploy it to S3, and invalidate the CloudFront cache whenever we push changes to our repository.

### 4.1. Create an IAM User for GitHub Actions

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

### 4.2. Add AWS Credentials to GitHub Secrets

1.  In your GitHub repository, go to **"Settings"** > **"Secrets and variables"** > **"Actions"**.
2.  Click **"New repository secret"** for each of the following secrets:
    *   `AWS_ACCESS_KEY_ID`: The Access Key ID you just created.
    *   `AWS_SECRET_ACCESS_KEY`: The Secret Access Key.
    *   `AWS_REGION`: The AWS region of your S3 bucket (e.g., `us-east-1`).
    *   `S3_BUCKET_NAME`: The name of your S3 bucket.
    *   `CLOUDFRONT_DISTRIBUTION_ID`: Go to your CloudFront distribution to find its ID (it's a string like `E1234567890ABC`).

### 4.3. Create the GitHub Actions Workflow

This workflow will run on every push to the `main` branch. It will build the React app, sync the build files to S3, and create a CloudFront invalidation.

1.  In your project, create a directory `.github/workflows`.
2.  Inside this directory, create a file named `deploy.yml`. The next section will provide the content for this file.
