# Setting Up AWS Infrastructure for the 03multihost Example

## Step 1 - Create an AWS Account
1. Go to https://aws.amazon.com and sign up for a free account.
2. Follow the on-screen instructions to complete the sign-up process.

## Step 2 - Launch EC2 Instances
1. Go to the EC2 Dashboard.
2. Click on "Launch Instance" to create a new EC2 instance.
4. Name this instance mserver.
4. Select the Amazon Linux 2 AMI.
5. Choose the free tier eligible instance type under the **Quick Start** tab (typically t2.micro or t3.micro, depending on availability in your region).
6. Set the root volume size to 9 GiB.
7. In the **Key Pair (login)** section, click **Create new key pair**.
Give it the name `mserve`, make sure .pem is selected as the private key file format, and then click "Create key pair".
The file `mserve.pem` will be automatically downloaded to your Downloads folder.
8. Click **Launch Instance** at the bottom right side of the page.


## Step 3 – Configure SSH for Simplicity

1. **Move the `.pem` file to your SSH directory**:  
   ```bash
   mv ~/Downloads/mserve.pem ~/.ssh/
   ```

2. **Set the correct permissions** (SSH will reject overly permissive keys):  
   ```bash
   chmod 400 ~/.ssh/mserve.pem
   ```

3. **Create an SSH alias** to simplify access:  
   Open the SSH config file:
   ```bash
   nano ~/.ssh/config
   ```
   Add the following block (replace `<mserve-instance-public-ip>` with your actual EC2 public IP):
   ```bash
   Host mserver
       HostName <mserve-instance-public-ip>
       User ec2-user
       IdentityFile ~/.ssh/mserve.pem
   ```
   You can find the public IP by navigating to the EC2 dashboard, clicking on **Instances**, and clicking on the instance ID of the instance just created. This will open the **Instance Summary** for mserver and the public IPv4 address will be listed. You can copy this and past it under HostName in the above configuration.

4. **Save and exit**:  
   Press `CTRL+X`, then `Y`, then `Enter` to save the file.

---

Now you can connect to your server with a simple command from any directory:

```bash
ssh mserver
```
## Step 4 - Transfer your KDB+ Set Up to Mserver

## Step 5 - Transfer Your License Key to the Instances
1. Use `scp` to transfer your personal license key to the mserver instance:
    ```bash
    scp /path/to/license.key mserver:~/q
    ```
Once these steps are completed, your AWS infrastructure will be set up and ready to run the 03multihost example.

## Step 6 - Clone the MServe GitHub Repo
1. SSH into your EC2 instance:
    ```bash
    ssh mserve
    ```
2. Install Git:
    ```bash
    sudo yum install git -y
    ```
3. Clone the MServe repository:
    ```bash
    git clone https://github.com/LLnCSoftware/mserve.git
    ```
