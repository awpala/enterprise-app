#!/usr/bin/env python3
"""Read-only AWS demo inventory; exit nonzero when project resources remain."""
import argparse
import concurrent.futures
import json
import subprocess
import sys


def is_project_name(name, prefixes):
    """Match exact project names or delimited children without prefix collisions."""
    return any(str(name) == prefix or str(name).startswith(prefix + separator)
               for prefix in prefixes for separator in ['-', '/', '.'])


def main():
    """Check all enabled regions and global resources with explicit account scope."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--account', required=True)
    parser.add_argument('--profile', required=True)
    parser.add_argument('--environment', choices=['dev', 'production', 'both'], default='both')
    args = parser.parse_args()
    prefixes = ['ea-dev', 'ea-prod'] if args.environment == 'both' else ['ea-' + ('prod' if args.environment == 'production' else 'dev')]

    def project(name):
        return is_project_name(name, prefixes)

    def tagged(tags):
        tags = {t['Key']: t['Value'] for t in tags or []}
        return tags.get('project') == 'ea' and 'ea-' + tags.get('environment', '') in prefixes

    def aws(region, *parts):
        result = subprocess.run(['aws', '--profile', args.profile, '--region', region, '--output', 'json', *parts], check=True, capture_output=True, text=True)
        return json.loads(result.stdout or '{}')

    if aws('us-east-1', 'sts', 'get-caller-identity')['Account'] != args.account:
        raise ValueError('Account does not match the requested account.')
    regions = [r['RegionName'] for r in aws('us-east-1', 'ec2', 'describe-regions')['Regions']]

    def inspect(region):
        findings = {}

        def record(name, values):
            if values:
                findings[name] = values

        rds = aws(region, 'rds', 'describe-db-instances')['DBInstances']
        record('databases', [r['DBInstanceIdentifier'] for r in rds if project(r['DBInstanceIdentifier']) or tagged(r.get('TagList'))])
        record('snapshots', [r['DBSnapshotIdentifier'] for r in aws(region, 'rds', 'describe-db-snapshots')['DBSnapshots'] if project(r['DBInstanceIdentifier'])])
        record('retained_backups', [r['DBInstanceIdentifier'] for r in aws(region, 'rds', 'describe-db-instance-automated-backups')['DBInstanceAutomatedBackups'] if project(r['DBInstanceIdentifier'])])
        record('repositories', [r['repositoryName'] for r in aws(region, 'ecr', 'describe-repositories')['repositories'] if project(r['repositoryName'])])
        record('efs', [r['FileSystemId'] for r in aws(region, 'efs', 'describe-file-systems')['FileSystems'] if tagged(r.get('Tags'))])
        record('alarms', [r['AlarmName'] for r in aws(region, 'cloudwatch', 'describe-alarms')['MetricAlarms'] if project(r['AlarmName'])])
        record('dashboards', [r['DashboardName'] for r in aws(region, 'cloudwatch', 'list-dashboards')['DashboardEntries'] if project(r['DashboardName'])])
        record('logs', [r['logGroupName'] for r in aws(region, 'logs', 'describe-log-groups')['logGroups'] if project(r['logGroupName'].removeprefix('/ecs/'))])
        record('active_secrets', [r['Name'] for r in aws(region, 'secretsmanager', 'list-secrets')['SecretList'] if project(r['Name'])])
        record('load_balancers', [r['LoadBalancerName'] for r in aws(region, 'elbv2', 'describe-load-balancers')['LoadBalancers'] if project(r['LoadBalancerName'])])
        record('clusters', [r for r in aws(region, 'ecs', 'list-clusters')['clusterArns'] if project(r.rsplit('/', 1)[-1])])
        record('namespaces', [r['Name'] for r in aws(region, 'servicediscovery', 'list-namespaces')['Namespaces'] if project(r['Name'])])
        vpcs = [r['VpcId'] for r in aws(region, 'ec2', 'describe-vpcs')['Vpcs'] if tagged(r.get('Tags'))]
        record('vpcs', vpcs)
        record('nat_gateways', [r['NatGatewayId'] for r in aws(region, 'ec2', 'describe-nat-gateways')['NatGateways'] if r['State'] != 'deleted' and (r['VpcId'] in vpcs or tagged(r.get('Tags')))])
        record('elastic_ips', [r['AllocationId'] for r in aws(region, 'ec2', 'describe-addresses')['Addresses'] if tagged(r.get('Tags'))])
        record('volumes', [r['VolumeId'] for r in aws(region, 'ec2', 'describe-volumes')['Volumes'] if tagged(r.get('Tags'))])
        return region, findings

    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for region, findings in pool.map(inspect, regions):
            results[region] = findings
    results['global'] = {}
    zones = [z['Name'] for z in aws('us-east-1', 'route53', 'list-hosted-zones')['HostedZones'] if project(z['Name'])]
    if zones:
        results['global']['hosted_zones'] = zones
    distributions = aws('us-east-1', 'cloudfront', 'list-distributions').get('DistributionList', {}).get('Items', [])
    remaining = [d['Id'] for d in distributions if project(d.get('Comment', '').split(' ')[0])]
    if remaining:
        results['global']['cloudfront'] = remaining
    print(json.dumps({'account': args.account, 'regions_checked': len(regions), 'inventory': results}, indent=2))
    return 1 if any(results.values()) else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f'Inventory verification failed: {error}', file=sys.stderr)
        sys.exit(2)
