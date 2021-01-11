# Auto deployment tags script

## Prerequisites:

- Install jq: <br>

  ```
  apt-get install jq
  ```
- Configure deploy.env file - [example](#deploy.env-file-example)


---

## Run the script :

- Run the script from the drive-project repo folder.

  Run Command:

  ```
  bash ./deployment.sh [flags]
  ```

#### Available Flags:

- **-h / --helm** - Run and update the z-helm charts tags
  - Current helm installed (v2.16.6)
- **-z / --zip** - Run and make a zip of the images

  - If you want to use the zip option, you must install p7zip package: 
    ```
    apt-get install p7zip 
    ```

- **-k / --kubectl** - Reinstall helm charts in kubernetes.
  - if you use this option you **must** specify the related fields in the file **deploy.env**: `(KBS_DNS, KBS_NAMESPACE, HELM_DEPLOY_NAME)`
  - Configured kubernetes
  - Helm installed (v2.16.6)
- **-g | --git** - git checkout all services tags
- **-f | --force** - force rebuild local images 
---
## deploy.env file example:
```
KBS_NAMESPACE="yaron"           # The name of the k8s namespace
KBS_DNS="kbs-yaron"             # The name of the k8s dns
HELM_DEPLOY_NAME="yaron-deploy" # Helm deployment name
JSON_FILE="services.dev.json"   # name of json services file
HELM_DEPENDENCIES=true          # reinstall helm dependencies

```
