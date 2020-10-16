#!/bin/bash

SSH_PRIVATE_KEY="$(cat ${GITKEYFILE})"
RTCLINK="https://<rtc-server>:<port>/jazz/"

echo "Creating executable file..."
mkdir jenkins
cd jenkins
cat <<-EOF > migration.sh
#!/bin/bash
echo "Workspace: /var/data"
cd /var/data
echo "Cloning repository ${GITREPOSITORY}"
git clone ${GITREPOSITORY} .
git checkout ${GITBRANCH}
git lfs install
git lfs track "*.zip"
git lfs track "*.gz"
echo "Loading target workspace ${TARGETWORKSPACE}"
scm load -i --force -r ${RTCLINK} -u ${RTCUSERNAME} -P '${RTCPASSWORD}' ${TARGETWORKSPACE}
echo "Initializing transfer from source workspace (current baseline) to target workspace (past baseline)..."
while : ; do
  scm migrate-to-git -r ${RTCLINK} -u ${RTCUSERNAME} -P '${RTCPASSWORD}' ${SOURCEWORKSPACE} ${TARGETWORKSPACE}
  if [ \$? -eq 0 ]; then
    break
  fi
  echo "Error happened. Trying to repair workspace..."
  scm repair -r ${RTCLINK} -u ${RTCUSERNAME} -P '${RTCPASSWORD}'
  scm unload -u ${RTCUSERNAME} -P '${RTCPASSWORD}' --ignore-uncommitted --delete --workspace ${TARGETWORKSPACE}
  scm load -i --force -r ${RTCLINK} -u ${RTCUSERNAME} -P '${RTCPASSWORD}' ${TARGETWORKSPACE}
  echo "Restarting migrate-to-git..."
done
echo "Push source..."
git push -u origin ${GITBRANCH}
EOF

cd ..

echo "Creating YAML file..."
cat <<-EOF > docker-compose.yaml
---
  version: "3"
  services:
    migrate:
      image: "rtc2git${BUILD_NUMBER}"
      build:
        context: "."
        args:
          - SSH_PRIVATE_KEY=.
      command: "/jenkins/migration.sh"
EOF

echo "Creating image and container..."
docker-compose -p migration${BUILD_NUMBER} build --build-arg SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY}"

echo "Starting process..."
docker-compose -p migration${BUILD_NUMBER} up

echo "Process finished."

# Do not leave keys or passwords in workspace
RTC2GITKEY=""
RTCPASSWORD=""
rm -f ./jenkins/migration.sh

echo "Deleting container and image..."
docker-compose -p migration${BUILD_NUMBER} down
docker rmi rtc2git${BUILD_NUMBER}
