# Get AD User E-mail Aliases

Get the e-mail aliases from Google for all users in Active Directory.

## Setup

### Create and activate a virtual environment

```bash
python -m venv ./.venv
source .venv/bin/activate
```

### Install dependencies

```bash
pip install -r requirements.txt
```

### Create and populate .env

### Create Google Credentials file


## Gemini

This script was originally produced using Google Gemini.  

Gemini Prompt

>  Write a Python script to list all the e-mail aliases a user has in Google. Query an OU in Active Directory named "Active Users" and for each user, use the EmployeeID attrribute with an added suffix "@nyu.edu" as the User ID to query the Google API. In CSV format, output the list of users and their e-mail addresses in two columns with the e-mail addresses separated by spaces. Authenticate to the Google API using a username and password. Log each action. Use a .env file to parameterize the output file path, the log file path, the connection to Active Directory, and the connection to the Google API. Include command line options. The first option produces a list of users from Active Directory in CSV format. Another option produces the full list of users and their e-mail aliases. Another option just tests the connections to Active Directory and the Google API but does not request data. 
