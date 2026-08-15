# ADR 0004 - AWS-generated HTTPS origin

## Status

Accepted. 2026-08-15. Supersedes the custom-domain and ACM requirement in ADR 0002.

## Context

ADR 0002 correctly required HTTPS for deployed Cognito callbacks but assumed that HTTPS required an operator-owned DNS name and ACM certificate. This dedicated application must deploy from a blank AWS account without involving any personal or externally managed domain. Azure already provides a generated HTTPS hostname, and the AWS implementation should provide equivalent zero-DNS deployment behavior.

## Decision

Put an AWS CloudFront distribution in front of the shared Application Load Balancer. Use the CloudFront default certificate and generated `cloudfront.net` hostname as the canonical application origin. Feed that generated HTTPS origin directly into Cognito callback/logout URLs, API CORS, UI runtime configuration, Terraform outputs, and smoke tests.

The ALB accepts HTTP origin traffic only from the AWS-managed CloudFront origin-facing prefix list. CloudFront disables application caching, forwards requests to the ALB, supports all application HTTP methods, and redirects viewers to HTTPS.

The supported deployment path does not accept a custom-domain input and does not create Route 53 hosted zones, DNS records, or ACM certificates.

## Consequences

- A blank AWS account can deploy without domain ownership, DNS propagation, certificate validation, or registrar access.
- Cognito receives a stable AWS-generated HTTPS callback origin in the same Terraform graph.
- The public hostname changes if the CloudFront distribution is destroyed and recreated, which is acceptable for this disposable dedicated environment.
- CloudFront adds a small cost and another managed resource but removes manual deployment friction and direct public ALB access.
