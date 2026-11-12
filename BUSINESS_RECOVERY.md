# MoveFlow AI — Business Continuity and Recovery Plan

Updated: November 12, 2026

## Business assets
- Public website: https://moveflowai.github.io/moveflow-ai/
- Source repository: https://github.com/MoveFlowAi/moveflow-ai
- Supabase project URL: https://jmatopczikrdrooxrtfy.supabase.co
- Supabase dashboard: https://supabase.com/dashboard
- Business contact: moveflowai@gmail.com
- Google Forms customer quote intake: https://docs.google.com/forms/d/e/1FAIpQLSd5DvXuHvs3Wu-Vvp4E8Ia01_spPHNq97Kpkdxj49ACoDoTKg/viewform?usp=dialog

## What exists
The website is hosted on GitHub Pages. The project has auth, dashboard and quote starter pages. Supabase stores the four database tables: companies, company_members, service_areas, leads. The quote page is not yet an automated lead router; the current Google Form is separate. Do not claim that the platform is ready to process real customer leads securely.

## If ChatGPT access is lost
1. Log in to GitHub and open the repository above. The website and code are independent of ChatGPT.
2. Log in to Supabase to access the database project.
3. Open the GitHub Pages URL to verify the public site.
4. Use this document to resume development with another tool or developer.

## Recovery and security actions the owner must complete
- GitHub: enable two-factor authentication; securely store recovery codes; add a passkey or backup authenticator where available.
- Supabase: enable account MFA; securely store recovery options; confirm account recovery email.
- Google: enable two-step verification; set recovery email/phone; export Forms and linked Sheets periodically.
- Store passwords, tokens and recovery codes in a reputable password manager, NOT in this repository or a shared document.
- Download GitHub repository ZIP: repository > Code > Download ZIP. Save offline and to a private cloud folder.
- Back up Supabase schema and data using plan-supported backup/export options. Securely store any exports containing customer personal information. Test restoration.
- Preserve original logo, branding assets, customer agreements and pricing documentation.
- Review company legal formation and domain registration with qualified support when appropriate.

## Routine
Monthly: confirm logins, download repository backup, export important database tables if available, check recovery settings, test site and company login.
Quarterly: review permissions, remove unnecessary access, and test recovery from a backup.

## Never commit
Database passwords, Supabase secret/service_role keys, private customer data, recovery codes, or API tokens.
