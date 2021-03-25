import os
from pathlib import Path
import re
import requests
import sys
import tarfile
import tempfile
import zipfile
import shutil


def cache_from_dropbox(url, dest, overwrite=False):
    error_msg = f'Error with get_dropbox_dir("{url}", "{dest}").'

    output_path = Path(dest).expanduser().resolve()
    parent_dir = output_path.parent

    if output_path.exists():
        if overwrite:
            if output_path.is_dir():
                shutil.rmtree(str(output_path))
            else:
                output_path.unlink()
        else:
            if output_path.is_dir() and os.listdir(dest):
                print(f"{dest} exists and is not empty. Assuming already cached.")
            else:
                print(f"{dest} exists. Assuming already cached.")

    parent_dir.mkdir(parents=True, exist_ok=True)

    try:
        headers = {"user-agent": "Wget/1.16 (linux-gnu)"}
        response = requests.get(url, stream=True, headers=headers)
        status_code = response.status_code
        if str(status_code) != "200":
            response_text_limit = 500
            response_text = str(response.text)
            if len(response_text) > response_text_limit:
                response_text = response_text[:response_text_limit] + "..."
            raise Exception(
                "\n".join(
                    [
                        error_msg,
                        f"status_code: {str(status_code)}",
                        str(response.headers),
                        response_text,
                    ]
                )
            )

        # 'content-disposition':
        # 'inline; filename="api.tar.gz"; filename*=UTF-8\'\'api.tar.gz'
        content_disposition_filename_re = re.compile(r'filename="(.+?)\.(.+)"')

        content_disposition = response.headers["content-disposition"]
        filename = None
        file_ext = None
        for x in content_disposition.split("; "):
            for match in content_disposition_filename_re.finditer(x):
                if match.group(2):
                    filename = match.group(1)
                    file_ext = match.group(2)
                    break

        with tempfile.TemporaryDirectory() as tmp_dir:
            if file_ext in set(["tar.gz", "zip"]):
                downloaded_file = f"{tmp_dir}/{filename}.{file_ext}"
                with open(downloaded_file, "wb") as f:
                    for chunk in response.iter_content(chunk_size=1024):
                        if chunk:
                            f.write(chunk)

                if file_ext == "zip":
                    zipfile_ref = zipfile.ZipFile(downloaded_file, "r")
                    zipfile_ref.extractall(output_path)
                    zipfile_ref.close()
                elif file_ext == "tar.gz":
                    tar = tarfile.open(downloaded_file)
                    tar.extractall(output_path)
                    tar.close()
                else:
                    raise Exception(
                        "\n".join([error_msg, "This shouldn't be reachable."])
                    )

            else:
                with open(output_path, "wb") as f:
                    for chunk in response.iter_content(chunk_size=1024):
                        if chunk:
                            f.write(chunk)

    except Exception:
        raise Exception("\n".join([error_msg, str(sys.exc_info()[0])]))
