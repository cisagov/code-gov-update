#!/usr/bin/env python

"""email-update.py is a tool for sending an updated code.gov JSON file.

Usage:
  email-update.py --from=EMAIL --to=EMAIL [--cc=EMAIL] [--reply=EMAIL]  --json=FILENAME --subject=SUBJECT --text=FILENAME --html=FILENAME [--log-level=LEVEL]
  email-update.py (-h | --help)

Options:
  -h --help         Show this message.
  --from=EMAIL      The email address from which the updated JSON file should be sent.
  --to=EMAIL        A comma-separated list email address where the updated JSON file should be sent.
  --cc=EMAIL        A comma-separated list email address where the updated JSON file should also be sent.
  --reply=EMAIL     The email address to use as the reply-to address when sending the updated JSON file.
  --json=FILENAME   The name of the updated JSON file.
  --subject=SUBJECT The subject to use when sending the updated JSON file.
  --text=FILENAME   The name of a file containing the plain text that is to be used as the body of the email when sending the updated JSON file.
  --html=FILENAME   The name of a file containing the HTML text that is to be used as the body of the email when sending the updated JSON file.
  --log-level=LEVEL If specified, then the log level will be set to the specified value.  Valid values are "debug", "info", "warn", and "error".

"""

from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import logging
import os

import boto3
import docopt


def main():
    """Compile and send the update."""
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
            f'"{log_level}" is not a valid logging level.  Possible values are debug, info, warn, and error.'
        )
        return 1

    # Handle some command line arguments
    from_email = args["--from"]
    to_email = args["--to"]
    cc_email = args["--cc"]
    reply_email = args["--reply"]
    json_filename = args["--json"]
    subject = args["--subject"]
    text_filename = args["--text"]
    html_filename = args["--html"]

    # Build up the MIME message to be sent
    msg = MIMEMultipart("mixed")
    msg["From"] = from_email
    logging.debug(f"Message will be sent from: {from_email}")
    msg["To"] = to_email
    logging.debug(f"Message will be sent to: {to_email}")
    if cc_email is not None:
        msg["CC"] = cc_email
        logging.debug(f"Message will be sent as CC to: {cc_email}")
    if reply_email is not None:
        msg["Reply-To"] = reply_email
        logging.debug(f"Replies will be sent to: {reply_email}")
    msg["Subject"] = subject
    logging.debug(f"Message subject is: {subject}")

    # Construct and attach the text body
    body = MIMEMultipart("alternative")
    with open(text_filename, "r") as text:
        t = text.read()
        body.attach(MIMEText(t, "plain"))
        logging.debug(f"Message plain-text body is: {t}")
    with open(html_filename, "r") as html:
        h = html.read()
        html_part = MIMEText(h, "html")
        # See https://en.wikipedia.org/wiki/MIME#Content-Disposition
        html_part.add_header("Content-Disposition", "inline")
        body.attach(html_part)
        logging.debug(f"Message HTML body is: {h}")
    msg.attach(body)

    # Attach JSON file
    with open(json_filename, "r") as attachment:
        json_part = MIMEApplication(attachment.read(), "json")
        # See https://en.wikipedia.org/wiki/MIME#Content-Disposition
        _, filename = os.path.split(json_filename)
        json_part.add_header("Content-Disposition", "attachment", filename=filename)
        logging.debug(f"Message will include file {json_filename} as attachment")
    msg.attach(json_part)

    # Send the email
    ses_client = boto3.client("ses")
    response = ses_client.send_raw_email(RawMessage={"Data": msg.as_string()})
    # Check for errors
    status_code = response["ResponseMetadata"]["HTTPStatusCode"]
    if status_code != 200:
        logging.error(f"Unable to send message.  Response from boto3 is: {response}")
        return 2

    # Stop logging and clean up
    logging.shutdown()


if __name__ == "__main__":
    main()
