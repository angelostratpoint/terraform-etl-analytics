# CDCU SageMaker Processing Image

This is the minimal container image for the CDCU SageMaker Pipeline processing
step.

The image intentionally includes only Python 3.12 and pip. CDCU Python package
dependencies are installed at runtime from the approved UAT wheelhouse:

```text
s3://cdcu-uat-data-lake/artifacts/python-wheelhouse/
```

The runtime entry point is supplied by the SageMaker Pipeline definition:

```text
/opt/ml/processing/input/code/run_matching_prod.py
```

## Terraform-Managed ECR Deployment

Terraform can create the UAT ECR repository using:

```hcl
enable_sagemaker_processing_image_repository = true
sagemaker_processing_image_repository_name   = "cdcu-uat-sagemaker-processing"
sagemaker_processing_image_tag               = "py312"
```

If Docker is available on the deployment host, Terraform can also build and
push the image by setting:

```hcl
enable_sagemaker_processing_image_build = true
```

Keep the build flag disabled when the deployment host does not have Docker
installed/running.

## Manual Build And Push Example

Run this from a BPI-MS approved workstation or build environment with Docker,
AWS CLI, and ECR permissions.

```bash
export AWS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="765875313224"
export IMAGE_REPO="cdcu-uat-sagemaker-processing"
export IMAGE_TAG="py312"

aws ecr create-repository \
  --repository-name "${IMAGE_REPO}" \
  --region "${AWS_REGION}" || true

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build \
  -t "${IMAGE_REPO}:${IMAGE_TAG}" \
  docker/sagemaker-processing

docker tag \
  "${IMAGE_REPO}:${IMAGE_TAG}" \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_REPO}:${IMAGE_TAG}"

docker push \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_REPO}:${IMAGE_TAG}"
```

Use this Terraform value after push:

```hcl
sagemaker_matching_pipeline_processing_image_uri = "765875313224.dkr.ecr.ap-southeast-1.amazonaws.com/cdcu-uat-sagemaker-processing:py312"
```

If BPI-MS uses a different repository name, account, or tag, use the approved
image URI instead.
