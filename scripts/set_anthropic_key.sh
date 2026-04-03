#!/bin/bash
# Usage: ./set_anthropic_key.sh YOUR_API_KEY
# Updates the ECS task definition with the Anthropic API key

if [ -z "$1" ]; then
  echo "Usage: $0 <anthropic-api-key>"
  exit 1
fi

API_KEY=$1
CLUSTER="palavracadabra-dev"
SERVICE="palavracadabra-dev-api"

# Get current task definition
TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].taskDefinition' --output text)
echo "Current task def: $TASK_DEF"

# Get the container definition and add/update the API key
CONTAINER_DEF=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.containerDefinitions' --output json)

# Add ANTHROPIC_API_KEY to environment
UPDATED=$(echo $CONTAINER_DEF | python3 -c "
import sys, json
defs = json.load(sys.stdin)
env = defs[0].get('environment', [])
# Remove existing key if present
env = [e for e in env if e['name'] != 'ANTHROPIC_API_KEY']
env.append({'name': 'ANTHROPIC_API_KEY', 'value': '$API_KEY'})
defs[0]['environment'] = env
print(json.dumps(defs))
")

# Get other task def properties
TASK_ROLE=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.taskRoleArn' --output text)
EXEC_ROLE=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.executionRoleArn' --output text)
CPU=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.cpu' --output text)
MEMORY=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.memory' --output text)
FAMILY=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.family' --output text)

# Register new task definition
NEW_TASK=$(aws ecs register-task-definition \
  --family $FAMILY \
  --task-role-arn $TASK_ROLE \
  --execution-role-arn $EXEC_ROLE \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu $CPU \
  --memory $MEMORY \
  --container-definitions "$UPDATED" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

echo "New task def: $NEW_TASK"

# Update the service
aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $NEW_TASK --force-new-deployment --query 'service.status' --output text
echo "Service updated. Deployment in progress..."
