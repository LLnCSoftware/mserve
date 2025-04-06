# Setting Up AWS Infrastructure for the 03multihost Example

## Step 1 - Create an AWS Account
1. Go to https://aws.amazon.com and sign up for a free account.
2. Follow the on-screen instructions to complete the sign-up process.

## Step 2 - Create Security Group to Configure Network Access

1. **Navigate to the EC2 Dashboard**: Under **Resources** click on **Security Groups**.

2. **Create a New Security Group**: Click on the **Create Security Group** button. Name the security group `mserve_security_group`. 

3. **Configure Inbound Rules**:  
   - Under the **Inbound Rules** section, click **Add Rule**. Using the **Type** dropdown, select **SSH**. Under **Source**, select **My IP**. 
   - Add another rule. Select the **Custom UDP** type and, under **Port Range**, enter `5000-5999`. 

4. **Configure Outbound Rules**:  
   Leave the default **Outbound** rule set to allow all traffic. 

5. **Click Create Security Group**:  
   Click **Create Security Group** to finalize the creation of your security group.

6. **Assign the Security Group to Instances**:  
   When launching your EC2 instances (Step 3), ensure that you select this security group under the **Configure Security Group** section. This will apply the security group settings to your instances.


## Step 2 - Launch EC2 Instance  
1. Go to the EC2 Dashboard.
2. Click on "Launch Instance" to create a new EC2 instance.
4. Name this instance mserver.
4. Select the Amazon Linux 2 AMI.
5. Choose the free tier eligible instance type under the **Quick Start** tab (typically t2.micro or t3.micro, depending on availability in your region).
6. In the **Key Pair (login)** section, click **Create new key pair**.
Give it the name `mserve_keypair`, make sure .pem is selected as the private key file format, and then click "Create key pair".
The file `mserve_keypair.pem` will be automatically downloaded to your Downloads folder.
7. Click **Launch Instance** at the bottom right side of the page.


## Step 3 – Configure SSH for Simplicity

1. **Move the `.pem` file to your SSH directory**:  
   If the `.ssh` directory does not exist, create it first:
   ```bash
   mkdir -p ~/.ssh
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
   `nano` will create the file if it does not already exist.   


   Add the following block (replace `<mserve-instance-public-ip>` with your actual EC2 public IP):
   ```bash
   Host mserver
       HostName <mserve-instance-public-ip>
       User ec2-user
       IdentityFile ~/.ssh/mserve.pem
   ```
   You can find the public IP by navigating to the EC2 dashboard, clicking on **Instances**, and clicking on the instance ID of the instance just created. This will open the **Instance Summary** for mserver and the public IPv4 address will be listed. You can copy this and paste it under `HostName` in the above configuration.

4. **Save and exit**:  
   Press `CTRL+X`, then `Y`, then `Enter` to save the file.

---

Now you can connect to your server with a simple command from any directory:

```bash
ssh mserver
```
## Step 4 - Transfer Your KDB+ Setup to mserver

Assuming you have already installed KDB+ and obtained a personal license key, follow these steps to transfer your KDB+ setup:

1. **Transfer the KDB+ `q` directory to mserver**:
   Use `scp` to securely copy the `q` directory to your mserver instance. The `-r` (recursive) flag is used to copy the entire directory:
   ```bash
   scp -r ~/q mserver:~
   ```

2. **KDB+ Installation Documentation**:
   For additional installation instructions, such as setting environment variables or installing `rlwrap`, refer to the official KDB+ installation guide:  
   [KDB+ Installation Guide](https://code.kx.com/q/learn/install/)

3. **For Non-Linux Environments**:
If you're working on a non-Linux environment (e.g., macOS), download the **l64** (Linux 64-bit) version of KDB+ and place it in the `q` directory where the **m64** file would normally reside. Then remove **m64**. You can accomplish this in one command:

    ```bash
    ssh mserver "rm ~/q/m64" && scp ~/path/to/l64 mserver:~/q
    ```



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
3. Following the prompt, name the image `mserve_example03` and click **Create Image**. This will.... . This process may take approximately 15 minutes.


## Step 8 - Launch Servant Instances
1. Navigate to the EC2 dashboard and click **Launch Instance**. 
2. Name the instance `servant1`.
3. In the **Application and OS Images (Amazon Machine Image)** section, select the **My AMIs** tab and choose `mserve_example03`.
4. Under the **Key Pair (login)** section, select the `mserve_keypair` key pair created earlier.
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