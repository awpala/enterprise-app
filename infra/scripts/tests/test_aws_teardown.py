"""Safety regression checks for destructive teardown boundaries."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('teardown', Path(__file__).parents[1] / 'aws-teardown.py')
teardown = importlib.util.module_from_spec(spec)
spec.loader.exec_module(teardown)

check_spec = importlib.util.spec_from_file_location('check', Path(__file__).parents[1] / 'aws-teardown-check.py')
check = importlib.util.module_from_spec(check_spec)
check_spec.loader.exec_module(check)


class TeardownSafetyTests(unittest.TestCase):
    def state(self, account='123456789012', environment='dev', module='module.postgres'):
        return {'resources': [{'mode': 'managed', 'module': module, 'type': 'aws_db_instance', 'name': 'this', 'instances': [{'attributes': {'arn': f'arn:aws:rds:us-east-1:{account}:db:ea-dev-postgres', 'tags_all': {'project': 'ea', 'environment': environment}}}]}]}

    def test_inventory_matches_cloudfront_and_resource_names(self):
        for name in ['ea-dev', 'ea-dev-postgres', 'ea-dev.internal.', 'ea-dev/rabbitmq/password']:
            with self.subTest(name=name):
                self.assertTrue(check.is_project_name(name, ['ea-dev']))
        for name in ['ea-development-db', 'ea-prod-postgres', 'unrelated-ea-dev']:
            with self.subTest(name=name):
                self.assertFalse(check.is_project_name(name, ['ea-dev']))

    def test_accepts_selected_application(self):
        teardown.validate_state(self.state(), '123456789012', 'dev')

    def test_rejects_other_account(self):
        with self.assertRaises(ValueError):
            teardown.validate_state(self.state(account='999999999999'), '123456789012', 'dev')

    def test_rejects_other_environment(self):
        with self.assertRaises(ValueError):
            teardown.validate_state(self.state(environment='prod'), '123456789012', 'dev')

    def test_rejects_bootstrap_and_unknown_modules(self):
        for module in ['', 'module.bootstrap', 'module.unrelated']:
            with self.subTest(module=module), self.assertRaises(ValueError):
                teardown.validate_state(self.state(module=module), '123456789012', 'dev')

    def test_rejects_creates_updates_and_replacements(self):
        for actions in [['create'], ['update'], ['delete', 'create'], ['create', 'delete']]:
            with self.subTest(actions=actions), self.assertRaises(ValueError):
                teardown.deletion_addresses({'resource_changes': [{'address': 'db', 'change': {'actions': actions}}]})

    def test_reads_and_noops_do_not_expand_delete_scope(self):
        changes = [{'address': action, 'change': {'actions': [action]}} for action in ['read', 'no-op', 'delete']]
        self.assertEqual(teardown.deletion_addresses({'resource_changes': changes}), ['delete'])


if __name__ == '__main__':
    unittest.main()
