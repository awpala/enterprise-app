# Customer SSO Bootstrap

Authentication uses one OIDC Authorization Code + PKCE contract, but identity resources and federation controls are provider adapters selected at deployment time.

| Target | Identity service | Procedure |
|---|---|---|
| Azure | Microsoft Entra External ID | [Azure SSO bootstrap](./azure-sso-manual-bootstrap.md) |
| AWS | Amazon Cognito with required Google and Microsoft/Outlook federation plus passwordless email OTP | [AWS deployment workbook](../workbooks/aws-deployment-workbook.md#3-authentication-and-client-parity) |

Do not copy credentials between providers or enable both provider configurations in one deployment. The selected Terraform root must supply the normalized authority, client ID, API scope, and logout endpoint consumed by the UI and API.
