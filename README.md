# Auto deployment tags script

## Prerequisites:

- Install jq: <br>

  ```
  apt-get install jq
  ```

- If your'e working on a local branch, make sure that your branch has published.

---

## Run the script :

- Run the script from the drive-project repo folder.

  Run Command:

  ```
  bash ./deployment.prod.sh
  ```

#### Available Options:

- **-h / --helm** - Run and update the z-helm charts tags
  - Helm installed (v2.16.6)
- **-z / --zip** - Run and make a zip of the images

  - If you want to use the zip option, you need to install p7zip: <br> `apt-get install p7zip `

- **-k / --kubectl** - Reinstall helm charts in kubernetes.
  - if you use this option you **must** specify the related fields in the script: <br> `(KBS_DNS, KBS_NAMESPACE, HELM_DEPLOY_NAME)`
  - Configured kubernetes
  - Helm installed (v2.16.6)
