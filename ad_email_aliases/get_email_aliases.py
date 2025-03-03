import ldap
import csv
import logging
import os
import argparse
from dotenv import load_dotenv
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Load environment variables from .env file
load_dotenv()

# Configuration from environment variables
OUTPUT_FILE_PATH = os.getenv("OUTPUT_FILE_PATH", "user_aliases.csv")
LOG_FILE_PATH = os.getenv("LOG_FILE_PATH", "alias_retrieval.log")
LDAP_SERVER_ADDRESS = os.getenv("LDAP_SERVER_ADDRESS")
LDAP_USERNAME = os.getenv("LDAP_USERNAME")
LDAP_USER_PASSWORD = os.getenv("LDAP_USER_PASSWORD")
LDAP_BASE_DN = os.getenv("LDAP_BASE_DN")
ORGANIZATIONAL_UNIT_NAME = os.getenv("ORGANIZATIONAL_UNIT_NAME", "Active Users")
GOOGLE_CREDENTIALS_FILE = os.getenv("GOOGLE_CREDENTIALS_FILE")

def test_ldap_connection(ldap_server, ldap_user, ldap_password, base_dn):
    """Tests the connection to Active Directory."""
    try:
        ldap_connection = ldap.initialize(ldap_server)
        ldap_connection.set_option(ldap.OPT_REFERRALS, 0)
        ldap_connection.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
        ldap_connection.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
        ldap_connection.simple_bind_s(ldap_user, ldap_password)
        ldap_connection.unbind_s()
        logging.info("LDAP connection successful.")
        return True
    except ldap.LDAPError as e:
        logging.error(f"LDAP connection failed: {e}")
        return False

def test_google_connection(google_creds_file):
    """Tests the connection to the Google API."""
    try:
        creds = Credentials.from_authorized_user_file(google_creds_file, ['https://www.googleapis.com/auth/admin.directory.user.readonly'])
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                logging.error("Google credentials invalid. Please regenerate.")
                return False
            with open(google_creds_file, 'w') as token:
                token.write(creds.to_json())

        service = build('admin', 'directory_v1', credentials=creds)
        service.users().aliases().list(userKey="nyu804@nyu.edu").execute() #Test with a simple API call.
        logging.info("Google API connection successful.")
        return True
    except Exception as e:
        logging.error(f"Google API connection failed: {e}")
        return False

def get_google_aliases(user_id, google_creds):
    """Retrieves all email aliases for a given user ID from Google."""
    try:
        service = build('admin', 'directory_v1', credentials=google_creds)
        results = service.users().aliases().list(userKey=user_id).execute()
        aliases = [alias['alias'] for alias in results.get('aliases', [])]
        return " ".join(aliases) if aliases else ""
    except HttpError as error:
        logging.error(f"Google API error for {user_id}: {error}")
        return ""
    except Exception as e:
        logging.error(f"Unexpected error for {user_id}: {e}")
        return ""

def get_active_directory_users(ldap_server, ldap_user, ldap_password, base_dn, ou_name):
    """Retrieves users from Active Directory."""
    try:
        ldap_connection = ldap.initialize(ldap_server)
        ldap_connection.set_option(ldap.OPT_REFERRALS, 0)
        ldap_connection.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
        ldap_connection.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
        ldap_connection.simple_bind_s(ldap_user, ldap_password)

        #search_filter = f"(&(objectCategory=person)(objectClass=user)(organizationalUnitName={ou_name}))"
        search_filter = f"(&(objectClass=user)(samaccountname=*))"
        search_results = ldap_connection.search_s(base_dn, ldap.SCOPE_SUBTREE, search_filter, ["employeeID", "sAMAccountName"])

        # print(search_filter)
        # print((base_dn, ldap.SCOPE_SUBTREE, search_filter, ["employeeID", "sAMAccountName"]))
        # print(search_results)

        users = []
        for dn, attributes in search_results:
            if 'employeeID' in attributes and attributes['employeeID']:
                employee_id = attributes['employeeID'][0].decode('utf-8')
                sam_account_name = attributes.get('sAMAccountName', [b''])[0].decode('utf-8')
                users.append((employee_id, sam_account_name))

        ldap_connection.unbind_s()
        # print(users)
        return users

    except ldap.LDAPError as e:
        logging.error(f"LDAP error: {e}")
        return []
    except Exception as e:
        logging.error(f"Unexpected LDAP error: {e}")
        return []

def main():
    """Main function to process users and retrieve email aliases."""

    logging.basicConfig(filename=LOG_FILE_PATH, level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    parser = argparse.ArgumentParser(description="Retrieve user email aliases from Google.")
    parser.add_argument("--test", action="store_true", help="Test connection to LDAP and Google API.")
    parser.add_argument("--adusers", action="store_true", help="Output list of Active Directory users in CSV format.")
    parser.add_argument("--aliases", action="store_true", help="Output list of users and their email aliases.")
    args = parser.parse_args()

    if args.test:
        test_ldap_connection(LDAP_SERVER_ADDRESS, LDAP_USERNAME, LDAP_USER_PASSWORD, LDAP_BASE_DN)
        test_google_connection(GOOGLE_CREDENTIALS_FILE)
        return

    try:
        creds = Credentials.from_authorized_user_file(GOOGLE_CREDENTIALS_FILE, ['https://www.googleapis.com/auth/admin.directory.user.readonly'])
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                logging.error("Google credentials invalid. Please regenerate.")
                return
            with open(GOOGLE_CREDENTIALS_FILE, 'w') as token:
                token.write(creds.to_json())

    except Exception as e:
        logging.error(f"Google credentials error: {e}")
        return

    users = get_active_directory_users(LDAP_SERVER_ADDRESS, LDAP_USERNAME, LDAP_USER_PASSWORD, LDAP_BASE_DN, ORGANIZATIONAL_UNIT_NAME)

    if not users:
        logging.warning("No users found in Active Directory.")
        return

    if args.adusers:
        with open("adusers.csv", 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            # writer.writerow(["sAMAccountName"])
            for employee_id, sam_account_name in users:
                writer.writerow([employee_id,sam_account_name])
        return

    if args.aliases:
        with open(OUTPUT_FILE_PATH, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["sAMAccountName", "Email Aliases"])
            for employee_id, sam_account_name in users:
                user_id = f"{employee_id}@nyu.edu"
                aliases = get_google_aliases(user_id, creds)
                writer.writerow([sam_account_name, aliases])
                logging.info(f"Processed {user_id}. Aliases: {aliases}")
        return

if __name__ == "__main__":
    main()