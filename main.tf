# Standard AWS Provider Block
terraform {
    required_version = ">= 1.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

data "aws_caller_identity" "current" {}

# Create private key
resource "tls_private_key" "PRI_KEY" {
    count = (length(var.KEYs) > 0 ?
            length(var.KEYs) : 0)
    algorithm = try(var.KEYs[count.index].ALGORITHM, "RSA") # "RSA" "ED25519"
    rsa_bits  = try(var.KEYs[count.index].RSA_SIZE, 4096) # "2048" "4096"
}

locals {
    KEYs = {
        for EACH, KEY in var.KEYs:
            EACH => {
                NAME = "${upper(KEY.NAME)}"
                KEY_PRI_FILE_TYPE = "${KEY.FILE_TYPE}"
                KEY_PRI_FILE_NAME = "${upper(KEY.NAME)}.${KEY.FILE_TYPE}"
                KEY_PRI_LINUX_FILE =  "${KEY.LINUX_DIR}/${upper(KEY.NAME)}.${KEY.FILE_TYPE}"
                KEY_PRI_WIN_FILE = "${KEY.WIN_DIR}/${upper(KEY.NAME)}.${KEY.FILE_TYPE}"
                KEY_PRI_RUNNER_FILE = "${KEY.RUNNER_DIR}/${upper(KEY.NAME)}.${KEY.FILE_TYPE}"
                KEY_PRI_S3_FILE = "${KEY.S3_DIR}/${upper(KEY.NAME)}.${KEY.FILE_TYPE}"
                KEY_PUB_LINUX_FILE =  "${KEY.LINUX_DIR}/${upper(KEY.NAME)}.pub"
                KEY_PUB_WIN_FILE =  "${KEY.WIN_DIR}/${upper(KEY.NAME)}.pub"
                KEY_PUB_RUNNER_FILE =  "${KEY.RUNNER_DIR}/${upper(KEY.NAME)}.pub"
                KEY_PUB_S3_FILE =  "${KEY.S3_DIR}/${upper(KEY.NAME)}.pub"
            }
    }
}

# Create key pair
resource "aws_key_pair" "CREATE_KEY" {
    count = (length(tls_private_key.PRI_KEY) > 0 ?
            length(tls_private_key.PRI_KEY) : 0)
    
    depends_on = [ tls_private_key.PRI_KEY ]
    key_name = local.KEYs[count.index].NAME
    public_key = tls_private_key.PRI_KEY[count.index].public_key_openssh

    provisioner "local-exec" {
        interpreter = ["bash", "-c"]
        command = <<-EOF
            if [[ -n "${var.KEYs[count.index].LINUX_DIR}" ]]; then
                mkdir -p "${var.KEYs[count.index].LINUX_DIR}"
                sudo echo "${tls_private_key.PRI_KEY[count.index].private_key_pem}" > "${local.KEYs[count.index].KEY_PRI_LINUX_FILE}"
                sudo chmod 400 "${local.KEYs[count.index].KEY_PRI_LINUX_FILE}"
                sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PRI_LINUX_FILE}"
                sudo echo "${tls_private_key.PRI_KEY[count.index].public_key_openssh}" > "${local.KEYs[count.index].KEY_PUB_LINUX_FILE}"
                sudo chmod 644 "${local.KEYs[count.index].KEY_PUB_LINUX_FILE}"
                sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PUB_LINUX_FILE}"
                if [[ -n "${var.KEYs[count.index].S3_DIR}" ]]; then
                    aws s3 cp "${local.KEYs[count.index].KEY_PRI_LINUX_FILE}" "s3://${local.KEYs[count.index].KEY_PRI_S3_FILE}" --profile ${var.PROFILE}
                    aws s3 cp "${local.KEYs[count.index].KEY_PUB_LINUX_FILE}" "s3://${local.KEYs[count.index].KEY_PUB_S3_FILE}" --profile ${var.PROFILE}
                fi
            fi
            if [[ -n "${var.KEYs[count.index].WIN_DIR}" ]]; then
                sudo echo "${tls_private_key.PRI_KEY[count.index].private_key_pem}" > "${local.KEYs[count.index].KEY_PRI_WIN_FILE}"
                sudo echo "${tls_private_key.PRI_KEY[count.index].public_key_openssh}" > "${local.KEYs[count.index].KEY_PUB_WIN_FILE}"
                if [[ -n "${var.KEYs[count.index].S3_DIR}" ]]; then
                    aws s3 cp "${local.KEYs[count.index].KEY_PRI_WIN_FILE}" "s3://${local.KEYs[count.index].KEY_PRI_S3_FILE}" --profile ${var.PROFILE}
                    aws s3 cp "${local.KEYs[count.index].KEY_PUB_WIN_FILE}" "s3://${local.KEYs[count.index].KEY_PUB_S3_FILE}" --profile ${var.PROFILE}
                fi
            fi
            if [[ -n "${var.KEYs[count.index].RUNNER_DIR}" ]]; then
                mkdir -p "${var.KEYs[count.index].RUNNER_DIR}"
                sudo echo "${tls_private_key.PRI_KEY[count.index].private_key_pem}" > "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
                sudo chmod 400 "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
                sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
                sudo echo "${tls_private_key.PRI_KEY[count.index].public_key_openssh}" > "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
                sudo chmod 644 "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
                sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
                if [[ -n "${var.KEYs[count.index].S3_DIR}" ]]; then
                    aws s3 cp "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}" "s3://${local.KEYs[count.index].KEY_PRI_S3_FILE}" --profile ${var.PROFILE}
                    aws s3 cp "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}" "s3://${local.KEYs[count.index].KEY_PUB_S3_FILE}" --profile ${var.PROFILE}
                fi
            fi
        EOF
    }
}

resource "null_resource" "name" {
    count = (length(tls_private_key.PRI_KEY) > 0 ?
            length(tls_private_key.PRI_KEY) : 0)
    triggers = {
        always_run = try("${var.KEYs[count.index].RUNNER_DIR}" != "" ? timestamp() : null, null)
    }
    provisioner "local-exec" {
        interpreter = ["bash", "-c"]
        command = <<-EOF
        if [[ -n "${var.KEYs[count.index].RUNNER_DIR}" ]]; then
            mkdir -p "${var.KEYs[count.index].RUNNER_DIR}"
            sudo echo "${tls_private_key.PRI_KEY[count.index].private_key_pem}" > "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
            sudo chmod 400 "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
            sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PRI_RUNNER_FILE}"
            sudo echo "${tls_private_key.PRI_KEY[count.index].public_key_openssh}" > "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
            sudo chmod 644 "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
            sudo chown $USER:$USER "${local.KEYs[count.index].KEY_PUB_RUNNER_FILE}"
        fi
        EOF
    }
}


# Remove private key when destroy
resource "null_resource" "REMOVE_KEY" {

    for_each = local.KEYs
    triggers = {
        KEY_PRI_WIN_FILE = try(each.value.KEY_PRI_WIN_FILE, "")
        KEY_PRI_LINUX_FILE = try(each.value.KEY_PRI_LINUX_FILE, "")
        KEY_PRI_RUNNER_FILE =  try(each.value.KEY_PRI_RUNNER_FILE, "")
        KEY_PRI_S3_FILE =  try(each.value.KEY_PRI_S3_FILE, "")
        KEY_PUB_WIN_FILE = try(each.value.KEY_PUB_WIN_FILE, "")
        KEY_PUB_LINUX_FILE = try(each.value.KEY_PUB_LINUX_FILE, "")
        KEY_PUB_RUNNER_FILE =  try(each.value.KEY_PUB_RUNNER_FILE, "")
        KEY_PUB_S3_FILE =  try(each.value.KEY_PUB_S3_FILE, "")
        PROFILE = "${var.PROFILE}"
    }

    provisioner "local-exec" {
        when    = destroy
        interpreter = ["bash", "-c"]
        command = <<-EOF
            if [ -n "${self.triggers.KEY_PRI_WIN_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PRI_WIN_FILE}"
                if [ -n "${self.triggers.KEY_PRI_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PRI_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
            if [ -n "${self.triggers.KEY_PUB_WIN_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PUB_WIN_FILE}"
                if [ -n "${self.triggers.KEY_PUB_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PUB_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
            if [ -n "${self.triggers.KEY_PRI_LINUX_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PRI_LINUX_FILE}"
                if [ -n "${self.triggers.KEY_PRI_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PRI_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
            if [ -n "${self.triggers.KEY_PUB_LINUX_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PUB_LINUX_FILE}"
                if [ -n "${self.triggers.KEY_PUB_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PUB_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
            if [ -n "${self.triggers.KEY_PRI_RUNNER_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PRI_RUNNER_FILE}"
                if [ -n "${self.triggers.KEY_PRI_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PRI_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
            if [ -n "${self.triggers.KEY_PUB_RUNNER_FILE}" ]; then
                sudo rm -rf "${self.triggers.KEY_PUB_RUNNER_FILE}"
                if [ -n "${self.triggers.KEY_PUB_S3_FILE}" ]; then
                    aws s3 rm "s3://${self.triggers.KEY_PUB_S3_FILE}" --profile ${self.triggers.PROFILE}
                fi
            fi
        EOF
    }
}