# Setting Up AWS Infrastructure for the 03multihost Example

## Step 1 - Create an AWS Account
1. Go to https://aws.amazon.com and sign up for a free account.
2. Follow the on-screen instructions to complete the sign-up process.

## Step 2 - Launch EC2 Instances
1. Go to the EC2 Dashboard.
2. Click on "Launch Instance" to create a new EC2 instance.
3. Select the Amazon Linux 2 AMI.
4. Choose the free tier eligible instance type (typically t2.micro or t3.micro, depending on availability in your region).
5. Set the root volume size to 9 GiB.
6. Set up a key pair for SSH access. Download and store this key file securely.

## Step 3 - Configure SSH for Simplicity
1. To simplify SSH access, create SSH aliases in your `~/.ssh/config` file.
2. Example configuration:
    ```bash
    Host mserver
        HostName <mserve-instance-public-ip>
        User ec2-user
        IdentityFile /path/to/your-key.pem

    Host servant1
        HostName <servant1-public-ip>
        User ec2-user
        IdentityFile /path/to/your-key.pem

    Host servant2
        HostName <servant2-public-ip>
        User ec2-user
        IdentityFile /path/to/your-key.pem
    ```
   This will allow you to SSH using simple commands like `ssh mserve`, `ssh servant1`, etc.

## Step 4 - Clone the MServe GitHub Repo
1. SSH into your EC2 instances:
    ```bash
    ssh mserve
    ```
2. Install Git:
    ```bash
    sudo yum install git -y
    ```
3. Clone the MServe repository:
    ```bash
    git clone https://github.com/your-repo/mserve.git
    ```

## Step 5 - Transfer Your License Key to the Instances
1. Use `scp` to transfer your personal license key to each instance using the aliases:
    ```bash
    scp /path/to/license.key mserver:~/q
    scp /path/to/license.key servant1:~/q
    scp /path/to/license.key servant2:~/q
    ```
Once these steps are completed, your AWS infrastructure will be set up and ready to run the 03multihost example.
