# Auto deployment tags script

Prerequisites before running the script:

- Install jq for wsl/linux:
  ` sudo apt-get install jq`

- If your'e working on a local branch, make sure that your branch has published.

- Run the script from the drive-project repo folder.

  Run:

  ```
  bash ./deployment.prod.sh
  ```

- Run and update the z-helm charts tags

  ```
  bash ./deployment.prod.sh --helm
  ```

- Run and make a zip of the images

  ```
  bash ./deployment.prod.sh --zip
  ```
