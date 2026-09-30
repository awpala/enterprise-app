#!/usr/bin/env python3
"""Plan and execute state-scoped AWS demo teardown; preserve bootstrap and state."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def run(args, *, capture=False):
    """Run an argument-safe command, failing immediately on errors."""
    result = subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def validate_state(state, account, environment):
    """Reject cross-account, cross-environment, and nonapplication state."""
    prefix = "ea-" + ("prod" if environment == "production" else "dev")
    modules = {"cloudfront", "cognito", "container_registry", "container_services", "ecs_cluster", "ecs_iam", "load_balancer", "networking", "observability", "postgres", "rabbitmq", "secrets_manager"}
    for resource in state['resources']:
        if resource['mode'] != 'managed':
            continue
        module = resource.get('module')
        if module not in {'module.' + name for name in modules}:
            if module or resource['type'] != 'random_password' or resource['name'] not in ('postgres', 'rabbitmq'):
                raise ValueError('Unexpected resource; bootstrap must not be in application state.')
        for instance in resource['instances']:
            value = instance['attributes']
            tags = value.get('tags_all') or value.get('tags') or {}
            if tags.get('project', 'ea') != 'ea' or tags.get('environment', prefix[3:]) != prefix[3:]:
                raise ValueError('Resource tags fall outside the selected application environment.')
            arn = value.get('arn', '')
            if arn.startswith('arn:aws:') and arn.split(':')[4] not in ('', account):
                raise ValueError('Resource belongs to another account.')


def deletion_addresses(result):
    """Reject any plan that could create or modify infrastructure."""
    deletions = []
    for change in result.get("resource_changes", []):
        actions = change["change"]["actions"]
        if actions not in (["delete"], ["no-op"], ["read"]):
            raise ValueError(f"Unexpected action at {change['address']}: {actions}")
        if actions == ["delete"]:
            deletions.append(change["address"])
    return deletions


def main():
    """Require explicit account, environment, backend, and reviewed plan directory."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['plan', 'apply'])
    parser.add_argument('--environment', required=True, choices=['dev', 'production'])
    parser.add_argument('--account', required=True)
    parser.add_argument('--profile', required=True)
    parser.add_argument('--region', required=True)
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--work-dir', required=True, type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    os.environ.update(AWS_PROFILE=args.profile, AWS_REGION=args.region, AWS_DEFAULT_REGION=args.region,
                      AWS_PAGER='', TF_IN_AUTOMATION='1', TF_INPUT='0')
    # Never inherit unrelated Terraform inputs from a deployment shell.
    for key in list(os.environ):
        if key.startswith('TF_VAR_') or key.startswith('TF_CLI_ARGS') or key == 'TF_DATA_DIR':
            del os.environ[key]
    aws = ['aws', '--profile', args.profile, '--region', args.region, '--output', 'json']

    def call(*parts):
        return json.loads(run(aws + list(parts), capture=True) or '{}')

    identity = call('sts', 'get-caller-identity')
    if identity['Account'] != args.account or identity['Arn'].endswith(':root'):
        raise ValueError('Expected account and a non-root identity are required.')
    work = args.work_dir.resolve()
    context = dict(account=args.account, region=args.region, bucket=args.bucket, environment=args.environment)
    prefix = 'ea-' + ('prod' if args.environment == 'production' else 'dev')
    source = Path(__file__).resolve().parents[1] / 'aws'

    if args.operation == 'plan':
        work.mkdir(parents=True, exist_ok=False)
        shutil.copytree(source, work / 'root', ignore=shutil.ignore_patterns('.terraform', '*.tfplan', '*.tfstate*', '*.deploy.env', 'terraform.tfvars', 'bootstrap'))
        (work / 'context.json').write_text(json.dumps(context))
    elif json.loads((work / 'context.json').read_text()) != context:
        raise ValueError('Arguments do not match the saved teardown context.')
    root = work / 'root'
    tf = ['terraform', f'-chdir={root}']
    run(tf + ['init', '-input=false', '-reconfigure', f'-backend-config=bucket={args.bucket}',
              f'-backend-config=region={args.region}', f'-backend-config=key=aws/{args.environment}.tfstate',
              '-backend-config=use_lockfile=true'])

    def read_state():
        return json.loads(run(tf + ['state', 'pull'], capture=True))

    def instances(state, kind):
        return [i['attributes'] for r in state['resources'] if r['mode'] == 'managed' and r['type'] == kind for i in r['instances']]


    def plan(name):
        destination = work / name
        run(tf + ['plan', '-destroy', '-input=false', '-lock-timeout=60s',
                  f'-var-file=envs/{args.environment}.tfvars', f'-out={destination}'])
        result = json.loads(run(tf + ['show', '-json', str(destination)], capture=True))
        return deletion_addresses(result)

    state = read_state()
    validate_state(state, args.account, args.environment)
    if args.operation == 'plan':
        (work / 'before.tfstate').write_text(json.dumps(state))
        values = {'cognito_domain_prefix': prefix + '-unused-teardown'}
        domains = instances(state, 'aws_cognito_user_pool_domain')
        if domains:
            values['cognito_domain_prefix'] = domains[0]['domain']
        # Recover protected provider inputs from existing state without printing secrets.
        for provider in instances(state, 'aws_cognito_identity_provider'):
            details = provider['provider_details']
            if provider['provider_type'] == 'Google':
                values.update(enable_google_identity_provider=True, google_client_id=details['client_id'], google_client_secret=details['client_secret'])
            elif provider['provider_type'] == 'OIDC':
                values['upstream_oidc'] = dict(name=provider['provider_name'], issuer=details['oidc_issuer'], client_id=details['client_id'], client_secret=details['client_secret'], scopes=details.get('authorize_scopes', 'openid profile email'))
            elif provider['provider_type'] == 'SAML':
                values['upstream_saml'] = dict(name=provider['provider_name'], metadata_url=details['MetadataURL'])
        (root / 'teardown.auto.tfvars.json').write_text(json.dumps(values))
        deletions = plan('review.tfplan')
        (work / 'approved-addresses.json').write_text(json.dumps(deletions, indent=2))
        print(f'Review plan: {work / "review.tfplan"}; {len(deletions)} deletions. No infrastructure changed.', flush=True)
        return

    original = json.loads((work / 'before.tfstate').read_text())
    if state['lineage'] != original['lineage'] or state['serial'] != original['serial']:
        raise ValueError('State changed since planning; prepare a new plan directory.')
    approved = set(json.loads((work / 'approved-addresses.json').read_text()))
    fresh = set(plan('preflight.tfplan'))
    if not fresh <= approved:
        raise ValueError('New deletions appeared after review; prepare a new plan.')
    # All exceptions are state-derived and verified against live project tags.
    # The disposable-demo policy accepts deletion without retained DB snapshots.
    for database in instances(state, 'aws_db_instance'):
        identifier = database['identifier']
        found = call('rds', 'describe-db-instances')['DBInstances']
        live = next((db for db in found if db['DBInstanceIdentifier'] == identifier), None)
        if not live:
            continue
        if f'module.postgres.aws_db_instance.this' not in approved:
            raise ValueError('Database deletion was not reviewed.')
        tags = {t['Key']: t['Value'] for t in live['TagList']}
        if tags.get('project') != 'ea' or tags.get('environment') != prefix[3:]:
            raise ValueError('Live RDS ownership does not match state.')
        if live['DeletionProtection']:
            call('rds', 'modify-db-instance', '--db-instance-identifier', identifier, '--no-deletion-protection', '--apply-immediately')
        if live['DBInstanceStatus'] != 'deleting':
            call('rds', 'delete-db-instance', '--db-instance-identifier', identifier, '--skip-final-snapshot', '--delete-automated-backups')
        print(f'Deleting {identifier}; waiting for completion.', flush=True)
        run(aws + ['rds', 'wait', 'db-instance-deleted', '--db-instance-identifier', identifier])
    for repository in instances(state, 'aws_ecr_repository'):
        name = repository['name']
        live = next((r for r in call('ecr', 'describe-repositories')['repositories'] if r['repositoryName'] == name), None)
        if live is None:
            continue
        tags = {t['Key']: t['Value'] for t in call('ecr', 'list-tags-for-resource', '--resource-arn', live['repositoryArn'])['tags']}
        if tags.get('project') != 'ea' or tags.get('environment') != prefix[3:]:
            raise ValueError('Live ECR ownership does not match state.')
        # Empty only the exact state-owned repository; Terraform deletes the repository.
        images = call('ecr', 'list-images', '--repository-name', name)['imageIds']
        for start in range(0, len(images), 100):
            result = call('ecr', 'batch-delete-image', '--repository-name', name, '--image-ids', json.dumps(images[start:start + 100]))
            if result.get('failures'):
                raise ValueError(f'ECR image deletion failed for {name}.')
    for lb in instances(state, 'aws_lb'):
        live = next((r for r in call('elbv2', 'describe-load-balancers')['LoadBalancers'] if r['LoadBalancerArn'] == lb['arn']), None)
        if live:
            tags = {t['Key']: t['Value'] for t in call('elbv2', 'describe-tags', '--resource-arns', lb['arn'])['TagDescriptions'][0]['Tags']}
            if tags.get('project') != 'ea' or tags.get('environment') != prefix[3:]:
                raise ValueError('Live load balancer ownership does not match state.')
            call('elbv2', 'modify-load-balancer-attributes', '--load-balancer-arn', lb['arn'], '--attributes', 'Key=deletion_protection.enabled,Value=false')
    remaining = set(plan('execute.tfplan'))
    if not remaining <= approved:
        raise ValueError('Unexpected resource deletion after pre-delete operations.')
    run(tf + ['apply', '-input=false', '-lock-timeout=60s', str(work / 'execute.tfplan')])
    final = read_state()
    (work / 'after.tfstate').write_text(json.dumps(final))
    if any(r['mode'] == 'managed' for r in final['resources']):
        raise ValueError('Managed resources remain in application state.')
    print('Application state is empty. Verify live regional inventory and subsequent billing separately.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f'Teardown stopped: {error}', file=sys.stderr)
        sys.exit(1)
