# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:light
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.4'
#       jupytext_version: 1.2.4
#   kernelspec:
#     display_name: Python3 - IPythonKernel
#     language: python
#     name: ipython_ipythonkernel
# ---

# %load_ext lab_black
# %load_ext sql

import ndex2.client
import os

# +
ndex_user = os.environ["NDEX_USER"]
ndex_pwd = os.environ["NDEX_PWD"]

if (not ndex_user) or (not ndex_pwd):
    raise Exception("Missing ndex_user and/or ndex_pwd")
else:
    print(ndex_user)

ndex_url = None
networkset_ids_by_name = dict()

if ndex_user == "wikipathways":
    ndex_url = "http://www.ndexbio.org"
    networkset_ids_by_name[
        "Published Pathway Figures - Analysis Set"
    ] = "85034b42-de8a-11ea-99da-0ac135e8bacf"
    networkset_ids_by_name[
        "WikiPathways Collection - Homo sapiens"
    ] = "453c1c63-5c10-11e9-9f06-0ac135e8bacf"
    networkset_ids_by_name[
        "CPTAC Cancer Hallmark Networks"
    ] = "9541cc61-4cf0-11e9-9f06-0ac135e8bacf"
elif ndex_user:
    ndex_url = "http://test.ndexbio.org"
    networkset_ids_by_name[
        "Published Pathway Figures - Analysis Set"
    ] = "8970df33-d6bd-11ea-9101-0660b7976219"
    networkset_ids_by_name[
        "wikipathways-gpml-Homo_sapiens"
    ] = "b44b7ca7-4da1-11e9-9fc6-0660b7976219"
else:
    raise Exception("No value set for ndex_user")
# -

# ## NDEx

# We log in as the current user.

my_ndex = ndex2.client.Ndex2(ndex_url, ndex_user, ndex_pwd)

# +
user_network_ids = set(my_ndex.get_network_ids_for_user(ndex_user))
print(len(user_network_ids))

# the following is a kludge. see this issue: https://github.com/ndexbio/ndex2-client/issues/78

return_limit = 100000

user_network_summaries = my_ndex.get_user_network_summaries(ndex_user, 0, return_limit)
user_network_summaries_count = len(user_network_summaries)
if user_network_summaries_count >= return_limit:
    raise Exception("User may have more networks than return_limit allows")

user_network_ids = set([x["externalId"] for x in user_network_summaries])
del user_network_summaries
print(len(user_network_ids))
# -

# a network is "filed" if it's in a networkset
filed_network_ids = set()
for networkset_id in list(networkset_ids_by_name.values()):
    for network_id in my_ndex.get_networkset(networkset_id)["networks"]:
        filed_network_ids.add(network_id)

print(len(user_network_ids))
print(len(filed_network_ids))
print(len(user_network_ids - filed_network_ids))
print(len(filed_network_ids - user_network_ids))

# If the current user has any networks that are not in at least one networkset, let's delete those "stray" networks.

for network_id in list(user_network_ids - filed_network_ids):
    try:
        network_summary = my_ndex.get_network_summary(network_id)
    except:
        user_network_ids.remove(network_id)
        continue

    if network_summary["owner"] != ndex_user:
        # appears a user can't delete a shared network
        continue

    if not "name" in network_summary:
        print(f"******* no name for {network_id}")
        print(network_summary)

    if network_summary["isReadOnly"]:
        my_ndex.set_read_only(network_id, False)

    try:
        my_ndex.delete_network(network_id)
        user_network_ids.remove(network_id)
    except:
        print(f"******* failed: {network_id}")
        print(network_summary)
        continue


