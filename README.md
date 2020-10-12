# Auto deployment tags script

Prerequisites before running the script:

- Install jq for wsl/linux:
  `apt-get install jq`

- If you want to use the zip option, you need to install p7zip:
  `apt-get install p7zip`

- If your'e working on a local branch, make sure that your branch has published.

- Configured kubernetes

- Helm installed

---

## Run the script :

- Run the script from the drive-project repo folder.

  Run Command:

  ```
  bash ./deployment.prod.sh
  ```

#### Available flags:

- **-h / --helm** - Run and update the z-helm charts tags
- **-z / --zip** - Run and make a zip of the images
- **-k / --kubectl** - Reinstall helm charts in kubernetes.
  - if you use this option you **must** specify the related fields in the script (KBS_DNS, KBS_NAMESPACE, HELM_DEPLOY_NAME)
