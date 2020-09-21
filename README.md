# Auto deployment tags script

Prerequisites before running the script:

- Install jq for wsl/linux:
  `apt-get install jq`

- If you want to use the zip option, you need to install p7zip:
  `apt-get install p7zip`

- If your'e working on a local branch, make sure that your branch has published.

---

## Run the script :

- Run the script from the drive-project repo folder.

  Run Command:

  ```
  bash ./deployment.prod.sh
  ```

#### Available flags:

- > **helm** - Run and update the z-helm charts tags
- > **zip** - Run and make a zip of the images
