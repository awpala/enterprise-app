# ADR 0004 - AWS-generated HTTPS origin

## Status

Accepted. 2026-08-15. Expands the AWS public-routing decision in ADR 0002.

## Context

Deployed Cognito callbacks require HTTPS, but this dedicated application must deploy from a blank AWS account without involving any personal or externally managed domain. The AWS implementation needs a generated HTTPS origin with no public-DNS prerequisite.

## Decision

Put an AWS CloudFront distribution in front of the shared Application Load Balancer. Use the CloudFront default certificate and generated `cloudfront.net` hostname as the canonical application origin. Feed that generated HTTPS origin directly into Cognito callback/logout URLs, API CORS, UI runtime configuration, Terraform outputs, and smoke tests.

The ALB accepts HTTP origin traffic only from the AWS-managed CloudFront origin-facing prefix list. CloudFront disables application caching, forwards requests to the ALB, supports all application HTTP methods, and redirects viewers to HTTPS.

The supported deployment path does not accept a custom-domain input and does not create public Route 53 hosted zones, public DNS records, or ACM certificates. Cloud Map separately creates private service-discovery DNS inside the VPC.

## Consequences

- A blank AWS account can deploy without domain ownership, DNS propagation, certificate validation, or registrar access.
- Cognito receives a stable AWS-generated HTTPS callback origin in the same Terraform graph.
- The public hostname changes if the CloudFront distribution is destroyed and recreated, which is acceptable for this disposable dedicated environment.
- CloudFront adds a small cost and another managed resource but removes manual deployment friction; the ALB security group blocks general internet source traffic and admits the AWS-managed CloudFront origin-facing prefix list.
