#!/usr/bin/env python3
# -*- coding: utf8 -*-

import os
import re
import shutil
import tarfile
import tempfile
import urllib.request

coresdk_url = "https://github.com/4Players/odin-sdk"
script_path = os.path.dirname(__file__)

def get_xcframework_version():
  file = open(os.path.join(script_path, "Sources", "OdinKit.swift"), "r")
  text = file.read()
  file.close()

  return re.findall("let version = \"([^\"]+)\"", text)[0]

if __name__ == "__main__":
  xcframework_version = get_xcframework_version()
  print("Downloading Odin.xcframework version", xcframework_version)

  xcframework_url = coresdk_url + "/releases/download/v" + xcframework_version + "/odin-xcframework.tgz"
  with urllib.request.urlopen(xcframework_url) as response:
    with tempfile.NamedTemporaryFile(delete = True) as tmp:
      shutil.copyfileobj(response, tmp)
      tar = tarfile.open(tmp.name)
      tar.extractall(os.path.join(script_path, "Frameworks"))
      tar.close()

  print("All done :-)")
