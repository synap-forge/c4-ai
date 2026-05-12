workspace "Discount Automation" "C4 System Landscape and Context for the discount solution." {

    !identifiers hierarchical

    model {
        user = person "Business Users" "Business users accessing discount capabilities."
        
        azureAD = softwareSystem "Azure Active Directory" "Microsoft cloud identity platform. Handles authentication via OAuth 2.0 / OpenID Connect. Issues JWT access tokens and ID tokens." "Existing System" {
            tenantDirectory = container "Tenant Directory" "Stores users, groups, and app registrations." "Azure AD Tenant"
            appRegistration = container "App Registration" "OAuth 2.0 client credentials, redirect URIs, and API permissions for the Discounts app." "Azure AD App"
            conditionalAccess = container "Conditional Access" "Enforces MFA, location, and device compliance policies." "Azure AD Policy"
        }

        azureGraph = softwareSystem "Microsoft Graph API" "Unified REST API to access Microsoft 365 data. Used for authorization: reading user group memberships, roles, and profile attributes." "Existing System" {
            groupsApi = container "Groups API" "GET /me/memberOf - returns Azure AD groups the signed-in user belongs to." "REST API"
            usersApi = container "Users API" "GET /me - returns profile, department, job title, etc." "REST API"
            rolesApi = container "Directory Roles API" "GET /me/transitiveMemberOf/microsoft.graph.directoryRole - returns assigned directory roles." "REST API"
        }

        // Phase 2: AWS managed services (external dependencies)
        awsSes = softwareSystem "AWS Simple Email Service (SES)" "Managed email sending service. Delivers lifecycle notification emails to stakeholders." "Existing System"
        awsTranslate = softwareSystem "AWS Translate" "Neural machine translation service. Translates discount names and descriptions for multi-locale support." "Existing System"

        // Store-network systems
        storeBoundary = group "Stores Boundary" {
            bbrApp = softwareSystem "BBR App" "Store tablet/phone app." "Mobile App,Existing System"
            mpos = softwareSystem "mPOS" "Mobile point-of-sale." "Mobile App,Existing System"
            xstore = softwareSystem "Xstore" "In-store POS system." "Existing System"
            xservices = softwareSystem "Xservices" "In-store integration services." "Existing System"
            xstoreLocalDb = softwareSystem "Xstore Local DB" "Local POS database." "Database ,Existing System"
        }
        
        bbrBoundary = group "BBR/mPOS Boundary" {
            bbrServices = softwareSystem "BBR Backend Service" "Backend phone app services." "Existing System"
        }

        // Retail-Service systems
        retailServiceBoundary = group "Retail Service Boundary" {
            apigateway = softwareSystem "API Gateway" "Kong API Gateway - external OAuth 2.0 enforcing gateway for mobile clients." "Gateway,Existing System"
            discountsSystem = softwareSystem "Discounts Optimazation System" "Primary discounts manager." {
                discountsDb = container "Discounts DB" "Primary discounts database. Stores discount records with lifecycle statuses (SUBMITTED / ACTIVE / FAILED / INACTIVE), full audit trail (who changed what, when, and previous value), and per-country guest group lists." "DocumentDB Database"
                appScheduler = container "EventBridge Scheduler" "Triggers MNT Scanner Lambda on schedule before MNT generation window."
                discountInactivationScheduler = container "EventBridge Inactivation Scheduler" "Phase 2: Triggers inactivation check after a discount expiry date passes. Sets discount status to INACTIVE." "AWS EventBridge"
                microSite = container "Web Application - Micro Site" "Frontend for discount management. Supports CREATE NEW and EDIT (activate/deactivate) operations. No delete option - edit is used to deactivate/reactivate discounts."
                discountService = container "Discount Service" "Backend service for discounts. Manages discount lifecycle statuses (SUBMITTED, ACTIVE, FAILED, INACTIVE) and persists full audit trail on every change."
                emailNotificationService = container "Email Notification Service" "Phase 2: AWS Lambda. Sends lifecycle email notifications: on discount submission, before scheduler runs, and after MNT is generated successfully or fails (after 5 retries)." "AWS Lambda"
                discountCreaterSQS = container "Message Queue for creating a MNT File" "AWS SQS for MNT file processing." "AWS SQS"
                discountMntScanner = container "Discount MNT File Scanner" "AWS Lambda for MNT file on EFS." "AWS Lambda By Pure Java"
                discountMntCreater = container "Discount MNT File creater" "AWS Lambda for MNT file on EFS." "AWS Lambda By Pure Java"
                storeApi = container "Store API" "Store-facing API (alternative path)."
            }
        }
        
        posBoundary = group "POS Boundary" {
            xcenterDb = softwareSystem "XCenter DB" "Central store operations DB." "Database, Existing System"
            xstoreDataFiles = softwareSystem "Xstore Data Files (EFS)" "Shared file store with Xstore DAT files." "Existing System"
        }

        // Core relationships
        user -> azureAD "User will authenricate by Azure AD"
        user -> azureGraph "User will authorize by Azure Graph"
        user -> discountsSystem.microSite "Uses via SSO / User Groups"
        discountsSystem.microSite -> discountsSystem.discountService "HTTPS / REST"
        discountsSystem.microSite -> discountsSystem.storeApi "HTTPS / REST"
        apigateway -> discountsSystem.discountService "HTTP(s)"
        apigateway -> discountsSystem.storeApi "HTTPS"
        discountsSystem.discountService -> discountsSystem.discountsDb "JDBC"
        
        // MNT File creation
        discountsSystem.appScheduler -> discountsSystem.discountMntScanner "Event Bridge"
        discountsSystem.discountMntScanner -> discountsSystem.discountsDb "JDBC"
        discountsSystem.discountMntScanner -> discountsSystem.discountCreaterSQS "SQS - AWS SDK"
        discountsSystem.discountCreaterSQS -> discountsSystem.discountMntCreater "SQS - AWS SDK"
        discountsSystem.discountsDb -> discountsSystem.discountMntCreater "JDBC"
        discountsSystem.discountMntCreater -> xstoreDataFiles "Writes MNT files on AWS EFS"
        xstoreDataFiles -> xcenterDb "Replicates/Synchronizes"
        
        bbrApp -> bbrServices "Consumes discount data via Kong API" "REST API / OAuth 2.0"
        mpos -> bbrServices "Consumes discount data via Kong API" "REST API / OAuth 2.0"
        bbrServices -> apigateway "Fetch all data from Discount Optimization System"
        mpos -> xservices "HTTP(s)"
        xservices -> xstoreLocalDb "Reads/Writes"
        xstore -> xstoreLocalDb "Reads/Writes"

        // Authentication flow
        user -> azureAD "Authenticates using" "OpenID Connect / OAuth 2.0"
        azureAD -> user "Login prompt + MFA" "OpenID Connect"
        azureAD -> discountsSystem.microSite "Returns ID token + access token to" "OAuth 2.0 Authorization Code + PKCE"
        discountsSystem.microSite -> azureAD.appRegistration "Registered in"
        discountsSystem.microSite -> azureAD "Validates token with" "JWKS / OIDC discovery"

        // Authorization flow
        discountsSystem.discountService -> azureAD "Validates JWT (JWKS)" "HTTPS / JWKS"
        discountsSystem.discountService -> azureGraph "Fetches user groups for RBAC" "HTTPS / REST"
        discountsSystem.discountService -> azureGraph.groupsApi "Checks group membership for feature access" "HTTPS"
        discountsSystem.discountService -> azureGraph.usersApi "Reads user profile / department" "HTTPS"

        // Phase 2: Email Notification flow
        discountsSystem.discountService -> discountsSystem.emailNotificationService "Triggers notification on discount submit / status change" "AWS SDK"
        discountsSystem.appScheduler -> discountsSystem.emailNotificationService "Triggers pre-scheduler run notification" "EventBridge"
        discountsSystem.discountMntCreater -> discountsSystem.emailNotificationService "Triggers post-MNT generation notification (success or failure after 5 retries)" "AWS SDK"
        discountsSystem.emailNotificationService -> awsSes "Sends notification emails via" "HTTPS / AWS SDK"

        // Phase 2: AWS Translate
        discountsSystem.discountService -> awsTranslate "Translates discount names/descriptions for multi-locale support" "HTTPS / AWS SDK"

        // Phase 2: Inactivation Scheduler
        discountsSystem.discountInactivationScheduler -> discountsSystem.discountService "Triggers expiry check - sets INACTIVE status for expired discounts" "EventBridge"
    }

    views {
        systemLandscape "SystemLandscape" "System landscape for Discount Automation." {
            include *
            autoLayout rl 80 80
        }

        systemContext discountsSystem "DiscountServiceContext" "Context view for the Discount Service." {
            include user
            include discountsSystem
            include azureAD
            include azureGraph
            include bbrServices
            include apigateway
            include xstoreDataFiles
            include awsSes
            include awsTranslate
            autoLayout tb
        }
        
        container discountsSystem "DiscountContainers" "Container view for the Discount Service." {
            include user
            include apigateway
            include discountsSystem.discountMntCreater
            include discountsSystem.appScheduler
            include discountsSystem.discountInactivationScheduler
            include discountsSystem.discountsDb
            include discountsSystem.discountService
            include discountsSystem.microSite
            include discountsSystem.storeApi
            include discountsSystem.discountCreaterSQS
            include discountsSystem.discountMntScanner
            include discountsSystem.emailNotificationService
            include xstoreDataFiles
            include azureAD
            include azureGraph
            include awsSes
            include awsTranslate
            autoLayout rl 100 100
        }

        dynamic discountsSystem "AuthFlow" "OAuth 2.0 Authorization Code + PKCE flow with Azure AD" {
            user -> discountsSystem.microSite "1. Opens app"
            discountsSystem.microSite -> azureAD "2. Redirect to /authorize (PKCE)"
            azureAD -> user "3. Login prompt + MFA"
            user -> azureAD "4. Submits credentials"
            azureAD -> discountsSystem.microSite "5. Returns authorization code"
            discountsSystem.microSite -> azureAD "6. Exchanges code for access + ID token"
            discountsSystem.microSite -> discountsSystem.discountService "7. Direct API call with Bearer token"
            discountsSystem.discountService -> azureAD "8. Validates JWT (JWKS)"
            discountsSystem.discountService -> azureGraph "9. GET /me/memberOf (groups)"
            bbrApp -> bbrServices "10. Mobile app fetch data"
            bbrServices -> apigateway "11. OAuth 2.0 token request via Kong Auth"
            apigateway -> discountsSystem.discountService "12. Forwards authenticated request"
            autoLayout
        }

        dynamic discountsSystem "NotificationFlow" "Phase 2 - Email Notification lifecycle for discount events" {
            user -> discountsSystem.microSite "1. Creates or edits a discount"
            discountsSystem.microSite -> discountsSystem.discountService "2. POST /discounts (status: SUBMITTED)"
            discountsSystem.discountService -> discountsSystem.discountsDb "3. Persists discount with SUBMITTED status + audit entry"
            discountsSystem.discountService -> discountsSystem.emailNotificationService "4. Trigger - discount submitted notification"
            discountsSystem.emailNotificationService -> awsSes "5. Send submission confirmation email"
            discountsSystem.appScheduler -> discountsSystem.emailNotificationService "6. Trigger - pre-scheduler notification"
            discountsSystem.emailNotificationService -> awsSes "7. Send pre-run alert email"
            discountsSystem.appScheduler -> discountsSystem.discountMntScanner "8. Start MNT scan"
            discountsSystem.discountMntScanner -> discountsSystem.discountCreaterSQS "9. Enqueue MNT creation"
            discountsSystem.discountCreaterSQS -> discountsSystem.discountMntCreater "10. Create MNT file"
            discountsSystem.discountMntCreater -> discountsSystem.emailNotificationService "11. Trigger - MNT success/failure notification"
            discountsSystem.emailNotificationService -> awsSes "12. Send MNT result email (success or FAILED after 5 retries)"
            autoLayout
        }

        styles {
            element "Person" {
                shape person
            }
            element "Database" {
                shape cylinder
            }
            element "Object Store" {
                shape cylinder
            }
            relationship "Relationship" {
                thickness 2
            }
            element "Element" {
                color #0773af
                stroke #0773af
                strokeWidth 10
                shape roundedbox
            }
            element "Bank Staff" {
                background #999999
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Existing System" {
                background #999999
                color #ffffff
                metadata false
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Web Browser" {
                shape WebBrowser
            }
            element "Mobile App" {
                shape MobileDevicePortrait
            }
            element "Database" {
                shape Cylinder
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Failover" {
                opacity 25
            }
            element "Boundary" {
                color #cc0000
                stroke #cc0000
                strokeWidth 10
                border solid
                background #fdf6f6
            }
            element "Gateway" {
                shape Hexagon
                background #003459
                color #ffffff
            }
        }
    }
}
