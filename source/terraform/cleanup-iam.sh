#!/bin/bash
# Script to remove IAM user/role created for Terraform deployment

set -e

echo "========================================="
echo "NovaPay Terraform IAM Cleanup"
echo "========================================="
echo ""

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is not installed"; exit 1; }

# Check AWS credentials (must have admin access to delete IAM resources)
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }

echo "⚠️  WARNING: This script will DELETE:"
echo "1. IAM user 'novapay-terraform-deploy'"
echo "2. All access keys for this user"
echo "3. IAM policy 'NovaPay-Terraform-Deploy'"
echo ""
echo "This action CANNOT be undone!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Get policy ARN
POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='NovaPay-Terraform-Deploy'].Arn" \
    --output text 2>/dev/null || echo "")

if [ -z "$POLICY_ARN" ]; then
    echo "ℹ Policy 'NovaPay-Terraform-Deploy' not found (may already be deleted)"
else
    echo "Found policy: $POLICY_ARN"
fi

# Check if user exists
USER_EXISTS=$(aws iam get-user --user-name novapay-terraform-deploy 2>/dev/null && echo "yes" || echo "no")

if [ "$USER_EXISTS" = "no" ]; then
    echo "ℹ User 'novapay-terraform-deploy' not found (may already be deleted)"
else
    echo "Found user: novapay-terraform-deploy"
    echo ""
    
    # Step 1: List and delete all access keys
    echo "Step 1: Deleting access keys..."
    ACCESS_KEYS=$(aws iam list-access-keys \
        --user-name novapay-terraform-deploy \
        --query 'AccessKeyMetadata[].AccessKeyId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ACCESS_KEYS" ]; then
        echo "  ℹ No access keys found"
    else
        for KEY_ID in $ACCESS_KEYS; do
            echo "  Deleting access key: $KEY_ID"
            aws iam delete-access-key \
                --user-name novapay-terraform-deploy \
                --access-key-id "$KEY_ID"
            echo "  ✓ Deleted: $KEY_ID"
        done
    fi
    
    # Step 2: Detach all managed policies
    echo ""
    echo "Step 2: Detaching managed policies..."
    ATTACHED_POLICIES=$(aws iam list-attached-user-policies \
        --user-name novapay-terraform-deploy \
        --query 'AttachedPolicies[].PolicyArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ATTACHED_POLICIES" ]; then
        echo "  ℹ No attached policies found"
    else
        for POLICY in $ATTACHED_POLICIES; do
            echo "  Detaching policy: $POLICY"
            aws iam detach-user-policy \
                --user-name novapay-terraform-deploy \
                --policy-arn "$POLICY"
            echo "  ✓ Detached: $POLICY"
        done
    fi
    
    # Step 3: Delete inline policies (if any)
    echo ""
    echo "Step 3: Deleting inline policies..."
    INLINE_POLICIES=$(aws iam list-user-policies \
        --user-name novapay-terraform-deploy \
        --query 'PolicyNames[]' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$INLINE_POLICIES" ]; then
        echo "  ℹ No inline policies found"
    else
        for POLICY_NAME in $INLINE_POLICIES; do
            echo "  Deleting inline policy: $POLICY_NAME"
            aws iam delete-user-policy \
                --user-name novapay-terraform-deploy \
                --policy-name "$POLICY_NAME"
            echo "  ✓ Deleted: $POLICY_NAME"
        done
    fi
    
    # Step 4: Remove user from groups (if any)
    echo ""
    echo "Step 4: Removing user from groups..."
    USER_GROUPS=$(aws iam list-groups-for-user \
        --user-name novapay-terraform-deploy \
        --query 'Groups[].GroupName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$USER_GROUPS" ]; then
        echo "  ℹ User not in any groups"
    else
        for GROUP_NAME in $USER_GROUPS; do
            echo "  Removing from group: $GROUP_NAME"
            aws iam remove-user-from-group \
                --user-name novapay-terraform-deploy \
                --group-name "$GROUP_NAME"
            echo "  ✓ Removed from: $GROUP_NAME"
        done
    fi
    
    # Step 5: Delete MFA devices (if any)
    echo ""
    echo "Step 5: Deleting MFA devices..."
    MFA_DEVICES=$(aws iam list-mfa-devices \
        --user-name novapay-terraform-deploy \
        --query 'MFADevices[].SerialNumber' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$MFA_DEVICES" ]; then
        echo "  ℹ No MFA devices found"
    else
        for SERIAL in $MFA_DEVICES; do
            echo "  Deactivating MFA device: $SERIAL"
            aws iam deactivate-mfa-device \
                --user-name novapay-terraform-deploy \
                --serial-number "$SERIAL"
            echo "  ✓ Deactivated: $SERIAL"
        done
    fi
    
    # Step 6: Delete login profile (if any)
    echo ""
    echo "Step 6: Deleting login profile..."
    aws iam delete-login-profile \
        --user-name novapay-terraform-deploy 2>/dev/null && \
        echo "  ✓ Login profile deleted" || \
        echo "  ℹ No login profile found"
    
    # Step 7: Delete SSH public keys (if any)
    echo ""
    echo "Step 7: Deleting SSH public keys..."
    SSH_KEYS=$(aws iam list-ssh-public-keys \
        --user-name novapay-terraform-deploy \
        --query 'SSHPublicKeys[].SSHPublicKeyId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$SSH_KEYS" ]; then
        echo "  ℹ No SSH keys found"
    else
        for KEY_ID in $SSH_KEYS; do
            echo "  Deleting SSH key: $KEY_ID"
            aws iam delete-ssh-public-key \
                --user-name novapay-terraform-deploy \
                --ssh-public-key-id "$KEY_ID"
            echo "  ✓ Deleted: $KEY_ID"
        done
    fi
    
    # Step 8: Delete service-specific credentials (if any)
    echo ""
    echo "Step 8: Deleting service-specific credentials..."
    SERVICE_CREDS=$(aws iam list-service-specific-credentials \
        --user-name novapay-terraform-deploy \
        --query 'ServiceSpecificCredentials[].ServiceSpecificCredentialId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_CREDS" ]; then
        echo "  ℹ No service-specific credentials found"
    else
        for CRED_ID in $SERVICE_CREDS; do
            echo "  Deleting credential: $CRED_ID"
            aws iam delete-service-specific-credential \
                --user-name novapay-terraform-deploy \
                --service-specific-credential-id "$CRED_ID"
            echo "  ✓ Deleted: $CRED_ID"
        done
    fi
    
    # Step 9: Delete signing certificates (if any)
    echo ""
    echo "Step 9: Deleting signing certificates..."
    SIGNING_CERTS=$(aws iam list-signing-certificates \
        --user-name novapay-terraform-deploy \
        --query 'Certificates[].CertificateId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$SIGNING_CERTS" ]; then
        echo "  ℹ No signing certificates found"
    else
        for CERT_ID in $SIGNING_CERTS; do
            echo "  Deleting certificate: $CERT_ID"
            aws iam delete-signing-certificate \
                --user-name novapay-terraform-deploy \
                --certificate-id "$CERT_ID"
            echo "  ✓ Deleted: $CERT_ID"
        done
    fi
    
    # Step 10: Delete the IAM user
    echo ""
    echo "Step 10: Deleting IAM user..."
    aws iam delete-user --user-name novapay-terraform-deploy
    echo "✓ User deleted: novapay-terraform-deploy"
fi

# Step 11: Delete the IAM policy (only if no other entities are using it)
if [ -n "$POLICY_ARN" ]; then
    echo ""
    echo "Step 11: Deleting IAM policy..."
    
    # Check if policy is attached to any other entities
    POLICY_ATTACHMENTS=$(aws iam list-entities-for-policy \
        --policy-arn "$POLICY_ARN" \
        --query 'length(PolicyUsers) + length(PolicyGroups) + length(PolicyRoles)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$POLICY_ATTACHMENTS" != "0" ]; then
        echo "  ⚠️  Policy is still attached to other entities"
        echo "  Skipping policy deletion for safety"
        echo "  To delete manually:"
        echo "    aws iam delete-policy --policy-arn $POLICY_ARN"
    else
        # Delete all non-default policy versions first
        POLICY_VERSIONS=$(aws iam list-policy-versions \
            --policy-arn "$POLICY_ARN" \
            --query 'Versions[?!IsDefaultVersion].VersionId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$POLICY_VERSIONS" ]; then
            echo "  Deleting old policy versions..."
            for VERSION in $POLICY_VERSIONS; do
                echo "    Deleting version: $VERSION"
                aws iam delete-policy-version \
                    --policy-arn "$POLICY_ARN" \
                    --version-id "$VERSION"
            done
        fi
        
        # Delete the policy
        aws iam delete-policy --policy-arn "$POLICY_ARN"
        echo "✓ Policy deleted: NovaPay-Terraform-Deploy"
    fi
fi

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""
echo "All IAM resources have been removed:"
echo "✓ IAM user 'novapay-terraform-deploy' deleted"
echo "✓ All access keys deleted"
echo "✓ IAM policy 'NovaPay-Terraform-Deploy' deleted"
echo ""
echo "Note: If you had AWS CLI profiles configured, you may want to remove them:"
echo "  Edit ~/.aws/credentials and ~/.aws/config"
echo "  Remove [novapay-terraform] profile section"
echo ""
