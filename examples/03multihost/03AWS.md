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
## Step 4 - Transfer your KDB+ Set Up to mserver
Assuming you have KDB+ installed and have attained a personal license key:  
1. Use `scp` to transfer your q directory to mserver
    ```bash
    scp -r ~/q mserver:~ 
    ```
The `-r` (recursive) flag is used to copy the entire directory.
See https://code.kx.com/q/learn/install/ for further installation instructions for KDB+ (setting environment variables, installing rlwrap, etc). 

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

## Step 7 - Create an EC2 AMI from the mserver Instance

1. Navigate to the EC2 Dashboard and click on **Instances** (you should now see at least 1 instance running).
2. Select the mserver instance by checking the checkbox next to it, then go to **Actions > Images and Templates > Create Image**.
3. Following the prompt, name the image `mserve_example03` and click **Create Image**. This process may take approximately 15 minutes.


## Step 8 - Launch Servant Instances
1. Navigate to the EC2 dashboard and click **Launch Instance**. 
2. Name the instance `servant1`.
3. In the **Application and OS Images (Amazon Machine Image)** section, select the **My AMIs** tab and choose `mserve_example03`.
4. Under the **Key Pair (login)** section, select the `mserve` key pair created earlier.
5. Click **Launch Instance**.
6. Repeat these steps to launch a third instance named `servant2`.

TODO: Add instructions throughout for setting up a security group configured properly for the example


## Step 9 - Update your SSH Config File

Next, update your SSH configuration file (`~/.ssh/config`) to include entries for each instance.

```bash
Host mserver
  HostName <mserver-instance-public-ip>
  User ec2-user
  IdentityFile ~/.ssh/mserve.pem

Host servant1
  HostName <servant1-instance-public-ip>
  User ec2-user
  IdentityFile ~/.ssh/mserve.pem

Host servant2
  HostName <servant2-instance-public-ip>
  User ec2-user
  IdentityFile ~/.ssh/mserve.pem
  ```