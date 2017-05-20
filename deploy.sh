#!/bin/sh
# global variables
ApplicationName="Your AWS Application Name"
GitRepo="Your Github Repo"
GitAPIKey="Your Github API Key"
HipChatToken="Your Hipchat Token"
HipChatRoomID="Your Hipchat Room Id."

# get last commit-id
COMMIT=`curl -u $GitAPIKey:x-oauth-basic https://api.github.com/repos/$GitRepo/git/refs/heads/$1 2>/dev/null | grep "sha" | cut -d\" -f4`

# run deployment
DEPLOY=`aws deploy create-deployment --application-name $ApplicationName --deployment-config-name CodeDeployDefault.OneAtATime --deployment-group-name $ApplicationName --region us-east-1 --description "Command line deployment by $(git config user.name)" --github-location repository=$GitRepo,commitId=$COMMIT | grep deploymentId | cut -d\" -f4`
echo Deployment Id: $DEPLOY

#Hipchat Alert with Link to AWS Deploy ID.
MESSAGE="$(git config user.name) started deploying the application/$1 to $1"
curl -H "Content-Type: application/json" \
-X POST \
-d "{\"color\": \"green\", \"message_format\": \"html\", \"message\": \"$MESSAGE\", \"card\": { \"style\": \"link\", \"url\": \"https://console.aws.amazon.com/codedeploy/home?region=us-east-1#/deployments/$DEPLOY\", \"format\" :\"medium\", \"id\":\"$DEPLOY\", \"title\": \"$MESSAGE\", \"description\": \"$DESCRIPTION\"}}" \
https://api.hipchat.com/v2/room/$HipChatRoomID/notification\?auth_token\=$HipChatToken

while true;
do
  echo 'Checking deployment status...'
  STATUS=`aws deploy get-deployment --deployment-id $DEPLOY | grep status | cut -d\" -f4`
  echo Current status: $STATUS	
	if [ "$STATUS" == "Succeeded" ] || [ "$STATUS" == "Failed" ] ; then
		if [ "$STATUS" == "Succeeded" ] ; then
			COLOR="green"
			MESSAGE="$(git config user.name) deploying your application/$1 to $1 succeeded."
		elif [ "$STATUS" == "Failed" ] ; then
			COLOR="red"
			MESSAGE="$(git config user.name) deploying your application/$1 to $1 has failed."
			DESCRIPTION=`aws deploy get-deployment --deployment-id $DEPLOY | grep message | cut -d\" -f4`
		fi	

	curl -H "Content-Type: application/json" \
    -X POST \
    -d "{\"color\": \"$COLOR\", \"message_format\": \"html\", \"message\": \"$MESSAGE\", \"card\": { \"style\": \"application\", \"url\": \"https://console.aws.amazon.com/codedeploy/home?region=us-east-1#/deployments/$DEPLOY\", \"format\" :\"medium\", \"id\":\"$DEPLOY\", \"title\": \"$MESSAGE\", \"description\": \"$DESCRIPTION\"}}" \
    https://api.hipchat.com/v2/room/$HipChatRoomID/notification\?auth_token\=$HipChatToken
    break
   fi
  sleep 3
 done