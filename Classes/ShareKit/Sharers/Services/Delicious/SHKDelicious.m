//
//  SHKDelicious.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/21/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKDelicious.h"
#import "OAuthConsumer.h"

@implementation SHKDelicious


- (id)init
{
	if (self = [super init])
	{		
		self.consumerKey = SHKDeliciousConsumerKey;		
		self.secretKey = SHKDeliciousSecretKey;
 		self.authorizeCallbackURL = [NSURL URLWithString:SHKDeliciousCallbackUrl];// HOW-TO: In your Twitter application settings, use the "Callback URL" field.  If you do not have this field in the settings, set your application type to 'Browser'.
		
		
		// -- //
		
		
		// You do not need to edit these, they are the same for everyone
	    self.authorizeURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/request_auth"];
	    self.requestURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/get_request_token"];
	    self.accessURL = [NSURL URLWithString:@"https://api.login.yahoo.com/oauth/v2/get_token"];
		
		self.signatureProvider = [[[OAPlaintextSignatureProvider alloc] init] autorelease];
	}	
	return self;
}


#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Delicious";
}

+ (BOOL)canShareURL
{
	return YES;
}


#pragma mark -
#pragma mark Authentication

- (void)tokenRequestModifyRequest:(OAMutableURLRequest *)oRequest
{
	[oRequest setOAuthParameterName:@"oauth_callback" withValue:authorizeCallbackURL.absoluteString];
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{
	[oRequest setOAuthParameterName:@"oauth_verifier" withValue:[authorizeResponseQueryVars objectForKey:@"oauth_verifier"]];
}

- (BOOL)handleResponse:(SHKRequest *)aRequest
{
	NSString *response = [aRequest getResult];
	
	if ([response isEqualToString:@"401 Forbidden"])
	{
		[self sendDidFailShouldRelogin];		
		return NO;		
	} 
	
	return YES;
}


#pragma mark -
#pragma mark Share Form

- (NSArray *)shareFormFieldsForType:(SHKShareType)type
{
	if (type == SHKShareTypeURL)
		return [NSArray arrayWithObjects:
				[SHKFormFieldSettings label:@"Title" key:@"title" type:SHKFormFieldTypeText start:item.title],
				[SHKFormFieldSettings label:@"Tags" key:@"tags" type:SHKFormFieldTypeText start:item.tags],
				[SHKFormFieldSettings label:@"Notes" key:@"text" type:SHKFormFieldTypeText start:item.text],
				[SHKFormFieldSettings label:@"Shared" key:@"shared" type:SHKFormFieldTypeSwitch start:SHKFormFieldSwitchOff],
				nil];
	
	return nil;
}



#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{	
	if ([self validateItem])
	{			
		OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.del.icio.us/v2/posts/add"]
																		consumer:consumer
																		   token:accessToken
																		   realm:nil
															   signatureProvider:nil];
		
		[oRequest setHTTPMethod:@"GET"];
				
		OARequestParameter *urlParam = [[OARequestParameter alloc] initWithName:@"url"
																		  value:SHKEncodeURL(item.URL)];
		
		OARequestParameter *descParam = [[OARequestParameter alloc] initWithName:@"description"
																		  value:SHKEncode(item.title)];
		
		OARequestParameter *tagsParam = [[OARequestParameter alloc] initWithName:@"tags"
																		  value:SHKEncode(item.tags)];
		
		OARequestParameter *extendedParam = [[OARequestParameter alloc] initWithName:@"extended"
																		  value:SHKEncode(item.text)];
		
		OARequestParameter *sharedParam = [[OARequestParameter alloc] initWithName:@"shared"
																		  value:[item customBoolForSwitchKey:@"shared"]?@"yes":@"no"];

		
		[oRequest setParameters:[NSArray arrayWithObjects:descParam, extendedParam, sharedParam, tagsParam, urlParam, nil]];
		[urlParam release];
		 [descParam release];
		 [tagsParam release];
		 [extendedParam release];
		 [sharedParam release];
		
		OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
							 delegate:self
					didFinishSelector:@selector(sendTicket:didFinishWithData:)
					  didFailSelector:@selector(sendTicket:didFailWithError:)];	
		
		[fetcher start];
		[oRequest release];
		
		// Notify delegate
		[self sendDidStart];
		
		return YES;
	}
	
	return NO;
}

- (void)sendTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{	
	if (ticket.didSucceed && [ticket.body rangeOfString:@"\"done\""].location != NSNotFound) 
	{
		// Do anything?
	}
	
	else 
		// TODO - better error handling
		[self sendTicket:ticket didFailWithError:[SHK error:@"There was a problem saving to Delicious"]];
	
	// Notify delegate
	[self sendDidFinish];
}

- (void)sendTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[self sendDidFailWithError:error];
}



@end
