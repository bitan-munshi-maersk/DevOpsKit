<#
.Description
# Context class for indenity details. 
# Provides functionality to login, create context, get token for api calls
#>
using namespace Microsoft.IdentityModel.Clients.ActiveDirectory

class ContextHelper {
    
    static hidden [Context] $currentContext;
    
    #This will be used to carry current org under current context.
    static hidden [string] $orgName;
    hidden static [PSObject] GetCurrentContext()
    {
        return [ContextHelper]::GetCurrentContext($false);
    }

    hidden static [PSObject] GetCurrentContext([bool]$authNRefresh)
    {
        if( (-not [ContextHelper]::currentContext) -or $authNRefresh)
        {
            $clientId = [Constants]::DefaultClientId ;          
            $replyUri = [Constants]::DefaultReplyUri; 
            $adoResourceId = [Constants]::DefaultADOResourceId;
            [AuthenticationContext] $ctx = $null;

            $ctx = [AuthenticationContext]::new("https://login.windows.net/common");

            [AuthenticationResult] $result = $null;

            $azSKUI = $null;
            if ( !$authNRefresh -and ($azSKUI = Get-Variable 'AzSKADOLoginUI' -Scope Global -ErrorAction 'Ignore')) {
                if ($azSKUI.Value -eq 1) {
                    $PromptBehavior = [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always 
                    $PlatformParameters = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters -ArgumentList $PromptBehavior 
                    $result = $ctx.AcquireTokenAsync($adoResourceId, $clientId, [Uri]::new($replyUri),$PlatformParameters).Result;
                }
                else {
                    $PromptBehavior = [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto 
                    $PlatformParameters = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters -ArgumentList $PromptBehavior 
                    $result = $ctx.AcquireTokenAsync($adoResourceId, $clientId, [Uri]::new($replyUri),$PlatformParameters).Result;
                }
            }
            else {
                $PromptBehavior = [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto 
                $PlatformParameters = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters -ArgumentList $PromptBehavior 
                $result = $ctx.AcquireTokenAsync($adoResourceId, $clientId, [Uri]::new($replyUri),$PlatformParameters).Result;
            }

            [ContextHelper]::ConvertToContextObject($result)
        }
        return [ContextHelper]::currentContext
    }
    
    hidden static [PSObject] GetCurrentContext([System.Security.SecureString] $PATToken)
    {
        if(-not [ContextHelper]::currentContext)
        {
            [ContextHelper]::ConvertToContextObject($PATToken)
        }
        return [ContextHelper]::currentContext
    }

    static [string] GetAccessToken([string] $resourceAppIdUri) {
            return [ContextHelper]::GetAccessToken()   
    }

    static [string] GetAccessToken()
    {
        if([ContextHelper]::currentContext)
        {
            # Validate if token is PAT using lenght (PAT has lengh of 52), if PAT dont go to refresh login session.
            #TODO: Change code to find token type supplied PAT or login session token
            #if token expiry is within 2 min, refresh.
            if (([ContextHelper]::currentContext.AccessToken.length -ne 52) -and ([ContextHelper]::currentContext.TokenExpireTimeLocal -le [DateTime]::Now.AddMinutes(2)))
            {
                [ContextHelper]::GetCurrentContext($true);
            }
            return  [ContextHelper]::currentContext.AccessToken
        }
        else
        {
            return $null
        }
    }

    hidden [SubscriptionContext] SetContext([string] $subscriptionId)
    {
        if((-not [string]::IsNullOrEmpty($subscriptionId)))
              {
                     $SubscriptionContext = [SubscriptionContext]@{
                           SubscriptionId = $subscriptionId;
                           Scope = "/Organization/$subscriptionId";
                           SubscriptionName = $subscriptionId;
                     };
                     # $subscriptionId contains the organization name (due to framework).
                     [ContextHelper]::orgName = $subscriptionId;
                     [ContextHelper]::GetCurrentContext()                  
              }
              else
              {
                     throw [SuppressedException] ("OrganizationName name [$subscriptionId] is either malformed or incorrect.")
        }
        return $SubscriptionContext;
    }

    hidden [SubscriptionContext] SetContext([string] $subscriptionId, [System.Security.SecureString] $PATToken)
    {
        if((-not [string]::IsNullOrEmpty($subscriptionId)))
              {
                     $SubscriptionContext = [SubscriptionContext]@{
                           SubscriptionId = $subscriptionId;
                           Scope = "/Organization/$subscriptionId";
                           SubscriptionName = $subscriptionId;
                     };
                     # $subscriptionId contains the organization name (due to framework).
                     [ContextHelper]::orgName = $subscriptionId;
                     [ContextHelper]::GetCurrentContext($PATToken)         
              }
              else
              {
                     throw [SuppressedException] ("OrganizationName name [$subscriptionId] is either malformed or incorrect.")
        }
        return $SubscriptionContext;
    }

    static [void] ResetCurrentContext()
    {
        
    }

    hidden static ConvertToContextObject([PSObject] $context)
    {
        $contextObj = [Context]::new()
        $contextObj.Account.Id = $context.UserInfo.DisplayableId
        $contextObj.Tenant.Id = $context.TenantId 
        $contextObj.AccessToken = $context.AccessToken
        
        # Here subscription basically means ADO organization (due to framework).
        # We do not get ADO organization Id as part of current context. Hence appending org name to both Id and Name param.
        $contextObj.Subscription = [Subscription]::new()
        $contextObj.Subscription.Id = [ContextHelper]::orgName
        $contextObj.Subscription.Name = [ContextHelper]::orgName 
        
        $contextObj.TokenExpireTimeLocal = $context.ExpiresOn.LocalDateTime
        #$contextObj.AccessToken =  ConvertTo-SecureString -String $context.AccessToken -asplaintext -Force
        [ContextHelper]::currentContext = $contextObj
    }

    hidden static ConvertToContextObject([System.Security.SecureString] $patToken)
    {
        $contextObj = [Context]::new()
        $contextObj.Account.Id = [string]::Empty
        $contextObj.Tenant.Id =  [string]::Empty
        $contextObj.AccessToken = [System.Net.NetworkCredential]::new("", $patToken).Password
        
        # Here subscription basically means ADO organization (due to framework).
        # We do not get ADO organization Id as part of current context. Hence appending org name to both Id and Name param.
        $contextObj.Subscription = [Subscription]::new()
        $contextObj.Subscription.Id = [ContextHelper]::orgName
        $contextObj.Subscription.Name = [ContextHelper]::orgName 

        #$contextObj.AccessToken = $patToken
        #$contextObj.AccessToken =  ConvertTo-SecureString -String $context.AccessToken -asplaintext -Force
        [ContextHelper]::currentContext = $contextObj
    }

    static [string] GetCurrentSessionUser() {
        $context = [ContextHelper]::GetCurrentContext()
        if ($null -ne $context) {
            return $context.Account.Id
        }
        else {
            return "NO_ACTIVE_SESSION"
        }
    }

}