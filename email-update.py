#!/usr/bin/env python

"""email-update.py is a tool for sending an updated code.gov JSON file

Usage:
  email-update.py --from=EMAIL --to=EMAIL [--reply=EMAIL] [--log-level=LEVEL]
  email-update.py (-h | --help)

Options:
  -h --help            Show this message.
  -f --from=EMAIL      The email address from which the updated JSON file should be sent.
  -t --to=EMAIL        The email address where the updated JSON file should be sent.
  -r --reply=EMAIL     The email address to use as the reply-to address when sending the updated JSON file.
  -l --log-level=LEVEL If specified, then the log level will be set to the specified value.  Valid values are "debug", "info", "warn", and "error".

"""

from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import logging
import os

import boto3
import docopt


class UnableToSendError(Exception):
    """Raised when an error is encountered when attempting to send an
email message

    Attributes
    ----------
    response : dict
        The response returned by boto3.

    """

    def __init__(self, response):
        self.response = response


def main():
    # Parse command line arguments
    args = docopt.docopt(__doc__)

    # Set up logging
    log_level = logging.getLevelName(logging.WARNING)
    if args["--log-level"]:
        log_level = args["--log-level"]
    try:
        logging.basicConfig(
            format="%(asctime)-15s %(levelname)s %(message)s", level=log_level.upper()
        )
    except ValueError:
        logging.critical(
            f'"{log_level}" is not a valid logging level.  '
            f"Possible values are debug, info, warn, and error."
        )
        return 1

    # Handle some command line arguments
    from_email = args["--from"]
    to_email = args["--to"]
    reply_email = args["--reply"]

    msg = MIMEMultipart("mixed")
    msg["From"] = from_email
    msg["To"] = to_email
    # msg['CC'] = 'cameron.dixon@trio.dhs.gov'
    if reply_email is not None:
        msg["Reply-To"] = reply_email

    msg["Subject"] = "Hello"

    text_body = MIMEMultipart("alternative")
    text_body.attach(MIMEText("Hello sir!", "plain"))
    html_part = MIMEText("<h1>Hello, sir!</h1>", "html")
    # See https://en.wikipedia.org/wiki/MIME#Content-Disposition
    html_part.add_header("Content-Disposition", "inline")
    text_body.attach(html_part)
    msg.attach(text_body)

    json_filename = "code.json"
    with open(json_filename, "r") as attachment:
        json_part = MIMEApplication(attachment.read(), "json")
    # See https://en.wikipedia.org/wiki/MIME#Content-Disposition
    _, filename = os.path.split(json_filename)
    json_part.add_header("Content-Disposition", "attachment", filename=filename)
    msg.attach(json_part)

    ses_client = boto3.client("ses")
    response = ses_client.send_raw_email(RawMessage={"Data": msg.as_string()})

    # Check for errors
    status_code = response["ResponseMetadata"]["HTTPStatusCode"]
    if status_code != 200:
        logging.error(
            "Unable to send message.  " "Response from boto3 is: {}".format(response)
        )
        raise UnableToSendError(response)

    # Stop logging and clean up
    logging.shutdown()


if __name__ == "__main__":
    main()
