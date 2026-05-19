#!/usr/bin/env bash
#
# routebox infra deploy. Wraps cfn-lint + aws cloudformation deploy.
#
# Usage:  deploy.sh <stack> <env>
#   stack: network | iam | ecs-cluster | rds | ecr | secrets-bootstrap
#   env:   dev | staging | prod
#
# Notes:
#   - There is no enforcement that you don't apply prod params to a staging
#     stack name. Don't do that.
#   - Writes a deploy log to ~/.routebox/deploy-logs/<stack>-<env>-<ts>.log

# (no `set -euo pipefail` — was added once and broke the tail-events loop on
# stacks that take a while; reverted; never re-introduced.)

STACK="$1"
ENV="$2"

if [ -z "$STACK" ] || [ -z "$ENV" ]; then
    echo "usage: $0 <stack> <env>"
    echo "  stack: network | iam | ecs-cluster | rds | ecr | secrets-bootstrap"
    echo "  env:   dev | staging | prod"
    exit 1
fi

# Resolve repo root from the location of this script.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

TEMPLATE="$REPO_ROOT/cfn/$STACK/template.yaml"
PARAMS="$REPO_ROOT/cfn/params/$ENV.json"
STACK_NAME="routebox-$STACK-$ENV"
REGION="${AWS_REGION:-us-east-1}"

if [ ! -f "$TEMPLATE" ]; then
    echo "no template at $TEMPLATE"
    exit 1
fi
if [ ! -f "$PARAMS" ]; then
    echo "no params at $PARAMS"
    exit 1
fi

LOG_DIR="$HOME/.routebox/deploy-logs"
mkdir -p "$LOG_DIR"
TS=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/$STACK-$ENV-$TS.log"

log() {
    echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"
}

log "stack=$STACK env=$ENV stack-name=$STACK_NAME region=$REGION"
log "template=$TEMPLATE"
log "params=$PARAMS"
log "log=$LOG"

# 1. Lint.
log "running cfn-lint..."
cfn-lint "$TEMPLATE" 2>&1 | tee -a "$LOG"
LINT_RC=${PIPESTATUS[0]}
if [ "$LINT_RC" != "0" ]; then
    log "cfn-lint failed (rc=$LINT_RC). aborting."
    exit "$LINT_RC"
fi

# 2. Build the --parameter-overrides arg by extracting only the params this
#    template declares. Otherwise CFN errors on unknown params.
TEMPLATE_PARAMS=$(grep -E '^[[:space:]]{2}[A-Za-z][A-Za-z0-9]*:' "$TEMPLATE" \
    | awk '/^Parameters:/{flag=1; next} /^[A-Za-z]/{flag=0} flag {gsub(":",""); print $1}' \
    | head -100)
# ^^ slightly fragile awk — relies on Parameters: being a top-level key with
# 2-space-indented children and nothing weirder. Has worked so far.

# Reparse with python because awk on YAML keeps biting us.
TEMPLATE_PARAMS=$(python3 -c "
import yaml, sys
with open('$TEMPLATE') as f:
    t = yaml.safe_load(f)
for k in (t.get('Parameters') or {}).keys():
    print(k)
" 2>/dev/null)

if [ -z "$TEMPLATE_PARAMS" ]; then
    log "couldn't parse template params (python yaml not installed?). passing all."
    OVERRIDES=$(jq -r '.[] | "\(.ParameterKey)=\(.ParameterValue)"' "$PARAMS" | tr '\n' ' ')
else
    OVERRIDES=""
    for p in $TEMPLATE_PARAMS; do
        v=$(jq -r --arg k "$p" '.[] | select(.ParameterKey == $k) | .ParameterValue' "$PARAMS")
        if [ -n "$v" ]; then
            OVERRIDES="$OVERRIDES $p=$v"
        fi
    done
fi

log "parameter overrides:$OVERRIDES"

# 3. Deploy.
log "running aws cloudformation deploy..."
aws cloudformation deploy \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --parameter-overrides $OVERRIDES \
    --tags Environment=$ENV ManagedBy=cloudformation \
    2>&1 | tee -a "$LOG" &
DEPLOY_PID=$!

# 4. Tail events while the deploy runs. Slightly flaky — sometimes shows the
#    same event twice if it happens between polls. Good enough.
sleep 5
LAST_TS=""
while kill -0 "$DEPLOY_PID" 2>/dev/null; do
    EVENTS=$(aws cloudformation describe-stack-events \
        --region "$REGION" \
        --stack-name "$STACK_NAME" \
        --max-items 10 \
        --query 'StackEvents[*].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
        --output text 2>/dev/null \
        | sort)
    if [ "$EVENTS" != "$LAST_TS" ]; then
        echo "$EVENTS" | tee -a "$LOG"
        LAST_TS="$EVENTS"
    fi
    sleep 5
done

wait "$DEPLOY_PID"
DEPLOY_RC=$?

if [ "$DEPLOY_RC" = "0" ]; then
    log "deploy ok."
else
    log "deploy failed (rc=$DEPLOY_RC). check the log above + the AWS console."
fi

# 5. Print the final stack status.
aws cloudformation describe-stacks \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>&1 | tee -a "$LOG"

exit $DEPLOY_RC
