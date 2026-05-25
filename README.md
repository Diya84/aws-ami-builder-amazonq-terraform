# AMI Builder Using Amazon Q

A comprehensive Terraform solution for creating custom AMIs using AWS EC2 Image Builder with Amazon Q integration for automated infrastructure deployment.

## Overview

This solution provides a flexible, template-driven approach to create custom Windows and Linux AMIs based on your specific requirements. It includes:

- **Automated AMI Creation**: EC2 Image Builder pipelines with build and test phases
- **Amazon Q Integration**: Interactive prompts for configuration and deployment
- **Security Scanning**: ASH (Automated Security Helper) integration for comprehensive security validation
- **Template System**: Reusable components for different AMI types
- **Multi-Environment Support**: Configurable for dev, staging, and production

## Prerequisites

### Required Tools
- **Terraform** >= 1.4.0
- **AWS CLI** configured with appropriate permissions
- **Amazon Q Developer** (for interactive workflow)
  - **CLI Installation**: [Install Amazon Q CLI](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/cli-install.html)
  - **IDE Extension**: [VS Code](https://marketplace.visualstudio.com/items?itemName=AmazonWebServices.amazon-q-vscode) | [JetBrains](https://plugins.jetbrains.com/plugin/24267-amazon-q)
  - **Telemetry**: Enable Amazon Q to send usage data to AWS for tracking user interactions and workflow analytics
    - **VS Code**: Go to Settings → Search Amazon Q Telemetry → Make sure 'Enable Amazon Q to Send usage data to AWS' is Selected
    - **CLI**: Run `q settings` in terminal → Go to Preferences → Enable the Telemetry button
- **Git** for version control

### AWS Authentication Setup
Before using this solution, configure AWS CLI authentication:

#### Option 1: IAM User
```bash
# Install AWS CLI if not already installed
# macOS: brew install awscli
# Windows: Download from https://aws.amazon.com/cli/

# Configure with IAM user credentials
aws configure
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: us-west-2
# Default output format: json
```

#### Option 2: IAM Role
```bash
# Configure role-based access
aws configure set role_arn arn:aws:iam::ACCOUNT-ID:role/AMI-Builder-Role
aws configure set source_profile default
aws configure set region us-west-2
```

#### Option 3: AWS SSO
```bash
# Configure SSO access
aws configure sso
# Follow prompts for SSO URL and region
```

#### Verify Authentication
```bash
# Test AWS access
aws sts get-caller-identity

# Test required permissions
aws imagebuilder list-image-pipelines --region us-west-2
aws s3 ls
```

### AWS Requirements
- AWS account
- **Network Infrastructure** (must exist before deployment):
  - **VPC**: Existing VPC with internet connectivity
  - **Private Subnets**: At least one private subnet for secure AMI building
  - **NAT Gateway/Instance**: Required for private subnets to download packages and updates
  - **Route Tables**: Properly configured routing (0.0.0.0/0 → NAT Gateway for private subnets)
  - **Internet Gateway**: Attached to VPC for NAT Gateway connectivity
- IAM permissions (least privilege) - The user deploying this solution requires:
  - **EC2 Image Builder**: Full access to Image Builder service
  - **EC2**: Describe operations, security group management, tagging
  - **S3**: Bucket and object operations (scoped to `*ami-builder*` resources)
  - **IAM**: Role and instance profile management (scoped to `*ami-builder*` resources)
  - **KMS**: Key creation and management for encryption
  - **CloudWatch Logs**: Log group operations for KMS events
  - **STS**: GetCallerIdentity for account information

## How to Use This Solution

### Initial Setup

1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd ami-builder
   ```

2. **Install Amazon Q Prompts**:
   ```bash
   mkdir -p ~/.aws/amazonq/prompts
   cp amazonq/prompts/*.md ~/.aws/amazonq/prompts/
   ```

3. **Configure MCP Servers** in `~/.aws/amazonq/mcp.json`:
   ```json
   {
     "mcpServers": {
       "awslabs.terraform-mcp-server": {
         "command": "uvx",
         "args": ["awslabs.terraform-mcp-server@latest"],
         "env": {
           "FASTMCP_LOG_LEVEL": "ERROR"
         },
         "disabled": false,
         "autoApprove": []
       },
       "ash": {
         "command": "uvx",
         "args": [
           "--from=git+https://github.com/awslabs/automated-security-helper@v3.0.0",
           "ash",
           "mcp"
         ],
         "disabled": false,
         "autoApprove": []
       }
     }
   }
   ```

4. **Restart Amazon Q** extension in your IDE

### Usage Options

#### Option 1: Amazon Q Developer IDE

Use prompts with `@` reference:

- **Build AMI**: `@ami-builder-complete I need a Windows web server AMI`
- **Security Scan**: `@ASH-security-scan Scan my code for security issues`

#### Option 2: Amazon Q CLI

First open Q chat session, then use prompt reference:

```bash
# Step 1: Open Q chat session
q chat

# Step 2: Use prompt reference in the chat
Use amazonq/prompts/ami-builder-complete.md to create Windows web server AMI

# For security scan:
Use amazonq/prompts/ASH-security-scan.md to scan my code for security issues
```

## Directory Structure

### Core Infrastructure
```
.
├── main.tf                   # Root Terraform configuration
├── variables.tf              # Input variable definitions
├── outputs.tf                # Output value definitions
├── providers.tf              # AWS provider configuration
├── terraform.tfvars          # Variable values (customize here)
└── README.md                 # This documentation
```

### Reusable Module
```
modules/
└── image-builder/            # Reusable AMI builder module
    ├── main.tf              # Module resources (IAM, S3, Image Builder)
    ├── variables.tf         # Module input variables
    └── outputs.tf           # Module outputs (ARNs, IDs)
```

### AMI Components generated by Amazon Q
```
components/
└── [ami-type]/              # AMI-specific components
    ├── build/               # Build phase components
    │   ├── install-features.yaml
    │   ├── install-software.yaml
    │   └── install-agents.yaml
    └── test/                # Test phase components
        ├── verify-features.yaml
        ├── verify-software.yaml
        └── verify-agents.yaml
```

### Installation Scripts generated by Amazon Q
```
scripts/
├── common/                  # Shared scripts across all AMI types
│   ├── InstallChocolatey.ps1
│   ├── InstallCWAAgent.ps1
│   ├── InstallSecurityAgent.ps1
│   └── InstallSentinelAgent.ps1
└── [ami-type]/             # AMI-specific scripts
    ├── InstallWindowsFeatures.ps1
    ├── InstallSoftware.ps1
    └── tests/
        ├── VerifyWindowsFeatures.ps1
        └── VerifySoftware.ps1
```

### Amazon Q Integration
```
amazonq/prompts/
├── ami-builder-complete.md   # Main AMI builder workflow
└── ASH-security-scan.md      # Security scanning workflow
```

### Templates (Used by Amazon Q)
```
templates/
├── terraform.tfvars.template
├── component-templates/
│   ├── build-component.yaml.template
│   └── test-component.yaml.template
└── script-templates/
    ├── install-script.ps1.template
    └── verify-script.ps1.template
```

## Workflow

1. **Complete Initial Setup** above (first time only)

2. **Build AMI** using your preferred method:
   - **IDE**: `@ami-builder-complete I need a Windows web server AMI`
   - **CLI**: Open `q chat` then use `Use amazonq/prompts/ami-builder-complete.md to create Windows web server AMI`

3. **Follow interactive prompts** - Amazon Q will ask about:
   - Operating system (Windows/Linux)
   - Application type (Web server, App server, Database, etc.)
   - Required software and features
   - Security requirements
   - Infrastructure settings

4. **Review generated files** - Amazon Q creates:
   - `terraform.tfvars` with your configuration
   - Component YAML files for build/test phases
   - PowerShell/Bash scripts for installations
   - Module configuration in `main.tf`

5. **Security Scan**:
   - **IDE**: `@ASH-security-scan Scan my code for security issues`
   - **CLI**: Open `q chat` then use `Use amazonq/prompts/ASH-security-scan.md to scan my code for security issues`

6. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

Refer these [Screenshots](https://gitlab.aws.dev/nitverse/aws-ami-builder-amazonq-terraform/-/blob/main/Docs/README.md?ref_type=heads) to see how it works
## How Terraform Code Works

### Module-Based Architecture

The solution uses a reusable Terraform module pattern:

```hcl
# main.tf - Root configuration calls the module
module "[ami-name]_image_builder" {
  source = "./modules/image-builder"
  
  # Pass variables from terraform.tfvars
  name = var.name
  aws_region = var.aws_region
  vpc_id = var.vpc_id
  subnet_ids = var.subnet_ids
  # ... other variables
}
```

### Module Resources

The `modules/image-builder` creates:

1. **S3 Bucket**: Stores scripts and build logs with encryption
2. **IAM Roles**: Instance profiles for Image Builder with minimal permissions
3. **Security Groups**: Restrictive rules for build instances
4. **KMS Keys**: Customer-managed encryption for EBS and AMI
5. **Image Builder Components**: Build and test phases from generated YAML
6. **Image Recipe**: Combines base AMI with components
7. **Infrastructure Configuration**: Instance settings and networking
8. **Distribution Configuration**: AMI sharing and regional distribution
9. **Pipeline**: Automated monthly execution

### Resource Flow

```
terraform.tfvars → variables.tf → main.tf → module → AWS Resources
                                      ↓
                              Generated Components
                                      ↓
                               Image Builder Pipeline
                                      ↓
                                 Custom AMI
```

### Generated Module Block

Amazon Q appends a module block to `main.tf` for each AMI type:

```hcl
module "web_server_image_builder" {
  source = "./modules/image-builder"
  
  name = "web-server"
  build_file_name = "web-server-components.yaml"
  test_file_name = "web-server-test.yaml"
  # ... configuration specific to web server AMI
}
```

## Architecture

### Infrastructure Components

- **VPC**: Uses existing VPC with provided subnet IDs
- **Security Groups**: Configured for HTTPS (443) and RDP (3389) access
- **IAM Roles**: EC2 instance profiles with Image Builder and SSM permissions
- **KMS Keys**: Encryption for EBS volumes and AMI snapshots
- **S3 Bucket**: Storage for component files, scripts, and build logs

### Image Builder Pipeline

Each pipeline includes:
- **Image Recipe**: Defines source AMI and build/test components
- **Infrastructure Configuration**: Instance types, networking, and security
- **Distribution Configuration**: AMI sharing and encryption settings
- **Pipeline**: Automated execution with monthly schedule

### Build Process

1. **Requirements Collection**: Amazon Q gathers AMI specifications through interactive prompts
2. **Code Generation**: Creates Terraform configuration, YAML components, and installation scripts
3. **Script Upload**: Generated scripts uploaded to S3 bucket
4. **Image Building**: EC2 instances execute build steps based on user requirements
5. **Testing**: Verification scripts validate installations
6. **AMI Creation**: Successful builds create encrypted AMIs

## Generated Components

**Amazon Q creates the following based on your requirements:**

### Installation Scripts
- **Windows**: PowerShell scripts for software installation and configuration
- **Linux**: Bash scripts for package installation and system setup
- **Common**: Shared scripts for monitoring agents and security tools

### YAML Components
- **Build Components**: Define installation steps and software packages
- **Test Components**: Validation scripts to verify installations
- **Platform-Specific**: Tailored for Windows or Linux environments

### Terraform Configuration
- **terraform.tfvars**: Your specific configuration values
- **Module Block**: Added to main.tf for your AMI type
- **Resource Names**: Generated using your AMI name with underscores

### Script Execution Flow
1. **Build Phase**: Install required software and features based on your specifications
2. **Test Phase**: Verify all installations completed successfully
3. **Cleanup**: Remove temporary files and apply system updates
4. **Finalization**: Create encrypted AMI with your configurations


## Configuration Variables

**Amazon Q will prompt you for these values and generate terraform.tfvars automatically:**

### Required Information
- **AMI Name**: Unique identifier for your AMI
- **Platform**: Windows or Linux
- **Application Type**: Web server, app server, database, etc.
- **AWS Region**: Deployment region
- **VPC ID**: Existing VPC to use
- **Subnet IDs**: Subnets for building AMI
- **Software Requirements**: Specific packages and features needed

### Generated Configuration
- **Instance Types**: Optimized for your AMI type
- **Source AMI**: Latest base image for your platform
- **Security Settings**: Appropriate security groups and encryption
- **Distribution**: Target accounts and regions for AMI sharing
- **Access Logging**: S3 access logging configuration and retention settings
- **Access Logging**: S3 access logging with configurable retention
- **Versioning**: Automatic version management for components

## Supported AMI Types

The solution supports creating AMIs for Windows and Linux:

### Windows AMIs
- **Web Server**: IIS, .NET Framework, web development tools
- **Application Server**: Application runtime, middleware, monitoring
- **Database Server**: SQL Server, database tools, backup utilities
- **Domain Controller**: Active Directory, DNS, DHCP services
- **Custom**: User-defined software and configurations

### Linux AMIs
- **Web Server**: Apache/Nginx, PHP/Python/Node.js, SSL certificates
- **Application Server**: Java/Python/Node.js runtime, application frameworks
- **Database Server**: MySQL/PostgreSQL, database tools, backup scripts
- **Container Host**: Docker, Kubernetes tools, container runtime
- **Custom**: User-defined packages and configurations


## Security Features

### Encryption
- **EBS Volumes**: Encrypted with customer-managed KMS keys
- **AMI Snapshots**: Encrypted during distribution
- **S3 Objects**: Server-side encryption for scripts and logs

### KMS Monitoring & Compliance
- **Event Logging**: All KMS key activities logged to CloudWatch Logs (`/aws/kms/${ami-name}`)
- **Key Rotation**: Automatic annual rotation enabled for compliance
- **Audit Trail**: Comprehensive logging of key usage, rotation, and policy changes
- **Retention**: Configurable log retention (default: 90 days) with lifecycle management

### Access Logging & Monitoring
- **S3 Access Logging**: Comprehensive logging of all S3 bucket access with dedicated encrypted logs bucket
- **Log Retention**: Configurable retention periods (default: 90 days) with automatic lifecycle management
- **CloudWatch Agent**: System and application metrics (if requested)
- **Security Agents**: Endpoint monitoring and security (if requested)

### Network Security
- **VPC Isolation**: Uses existing VPC with provided subnets
- **Security Groups**: Restrictive rules (HTTPS 443, RDP 3389 only)
- **S3 Access**: Public access blocked, IAM-based access only

### Access Control
- **IAM Roles**: Least privilege principle
- **Instance Profiles**: Scoped permissions for Image Builder
- **Cross-Account**: Support for AMI sharing with target accounts

### Monitoring & Compliance
- **CloudWatch Agent**: System and application metrics (if requested)
- **Security Agents**: Endpoint monitoring and security (if requested)

## Outputs

After successful deployment:

```hcl
# Your AMI Builder Pipeline
[ami-name]_image_pipeline_arn

# Your AMI Recipe
[ami-name]_image_recipe_arn

# Infrastructure Resources
vpc_id
subnet_ids
s3_bucket_name
kms_events_log_group
```

## Monitoring & Troubleshooting

### Build Monitoring
- **AWS Console**: EC2 Image Builder → Pipelines → [pipeline-name]
- **CloudWatch Logs**: `/aws/imagebuilder/[pipeline-name]`
- **S3 Logs**: `s3://[bucket]/logs/[image-type]/`
- **KMS Events**: `/aws/kms/[ami-name]` - Key rotation, usage, and policy changes

### Common Issues

1. **Build Failures**
   - Check CloudWatch logs for detailed error messages
   - Verify S3 script paths and permissions
   - Ensure source AMI is available in the region

2. **Permission Errors**
   - Verify IAM roles have required permissions
   - Check S3 bucket policies and access
   - Ensure KMS key permissions for encryption

3. **Network Issues**
   - Verify existing VPC has internet access (NAT Gateway/Instance)
   - Check security group rules
   - Ensure provided subnets have proper routing

4. **Script Execution**
   - Validate PowerShell script syntax
   - Verify S3 object uploads completed

### Manual Pipeline Execution

```bash
# Trigger pipeline manually
aws imagebuilder start-image-pipeline-execution \
  --image-pipeline-arn [pipeline-arn]
```
