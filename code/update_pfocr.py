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

# +
import json
import ndex2.client
import os
import pandas as pd
from pathlib import Path

from caching import cache_from_dropbox

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

# ## Pathway Disease Assocations
#
# Alex did a gene enrichment analysis on the PFOCR data to get pathway-disease associations. He provided the data [here](https://github.com/wikipathways/pathway-figure-ocr/issues/16#issuecomment-611684935).

pathway_disease_url = (
    "https://www.dropbox.com/s/vgazcxdq4wsl5yk/pfocr_disease_map.tsv?dl=0"
)

pfocr_disease_map_f = "../data/pfocr_disease_map.tsv"
cache_from_dropbox(url=pathway_disease_url, dest=pfocr_disease_map_f)

pfocr_disease_df = pd.read_csv(pfocr_disease_map_f, sep="\t").rename(
    columns={"figid": "pfocr_id"}
)
pfocr_disease_df

disease_pfocr_ids = set(pfocr_disease_df["pfocr_id"])
len(disease_pfocr_ids)

# ## NDEx
#
# Let's get the current user's info from NDEx to check that we can connect correctly:

anon_ndex = ndex2.client.Ndex2(ndex_url)

anon_ndex.get_user_by_username(ndex_user)

# Now we'll log in as the current user:

my_ndex = ndex2.client.Ndex2(ndex_url, ndex_user, ndex_pwd)

# And we'll get the info for the PFOCR network set:

# +
pfocr_networkset_id = networkset_ids_by_name["Published Pathway Figures - Analysis Set"]

pfocr_networkset_data = my_ndex.get_networkset(pfocr_networkset_id)
pfocr_networkset_data.keys()
# -

len(pfocr_networkset_data["networks"])

sample_network = my_ndex.get_network_summary(pfocr_networkset_data["networks"][0])
sample_network.keys()

# I think we can't search for network by `pfocr_id`, because we didn't specify these networks should be indexed:
# ```
# Visibility: Public (not searchable)
# ```
#
# Was this just for test.ndexbio.org or for production too? I think we only index the network set, not the individual networks contained.
#
# How should we find `pfocr_id` by `network_id`? What does `include_groups` mean?

my_ndex.search_networks(
    search_string="PMC4660682__12967_2015_712_Fig5_HTML.jpg",
    account_name=ndex_user,
    start=0,
    size=100,
    include_groups=True,
)

# Let's get the mappings from `pfocr_id` to `network_id`:

# +
cached_pfocr_id_to_network_id_filepath = (
    f"../data/{ndex_user}_pfocr_id_to_network_id.json"
)

pfocr_id_to_network_id = dict()

cached_pfocr_id_to_network_id_f = (
    Path(cached_pfocr_id_to_network_id_filepath).expanduser().resolve()
)

if cached_pfocr_id_to_network_id_f.exists():
    with open(cached_pfocr_id_to_network_id_filepath, "r") as f:
        pfocr_id_to_network_id = json.load(f)
else:
    for network_id in pfocr_networkset_data["networks"]:
        network_summary = my_ndex.get_network_summary(network_id)
        properties = network_summary["properties"]

        pfocr_id = next(p for p in properties if p["predicateString"] == "pfocr_id")[
            "value"
        ]

        if pfocr_id != network_summary["name"]:
            raise Exception(
                f"Expected pfocr_id {pfocr_id} to equal network_summary['name'] {network_summary['name']}"
            )

        if not pfocr_id in pfocr_id_to_network_id:
            pfocr_id_to_network_id[pfocr_id] = network_id
        else:
            raise Exception(
                f"pfocr_id_to_network_id[{pfocr_id}] already set: {pfocr_id_to_network_id[pfocr_id]}"
            )

    with open(cached_pfocr_id_to_network_id_filepath, "w") as f:
        json.dump(pfocr_id_to_network_id, f)
# -

pfocr_disease_df["network_id"] = pfocr_disease_df["pfocr_id"].apply(
    lambda pfocr_id: pfocr_id_to_network_id.get(pfocr_id, None)
)
pfocr_disease_df[pfocr_disease_df["network_id"].notnull()]

for i, df in pfocr_disease_df[pfocr_disease_df["network_id"].notnull()].groupby(
    by="pfocr_id"
):
    network_id = df["network_id"].iloc[0]
    pfocr_id = df["pfocr_id"].iloc[0]

    # TODO: are either of these calls fine?
    my_ndex.set_read_only(network_id, False)
    # my_ndex.set_network_system_properties(network_id, {"readOnly": False})

    network_properties = my_ndex.get_network_summary(network_id)["properties"]

    # Here's a sample of a disease property value from a WikiPathways network:
    # <a href="https://identifiers.org/doid/DOID:332">ALS</a>, <a href="https://identifiers.org/doid/DOID:332">amyotrophic lateral sclerosis</a>

    disease_links = list()
    for i, subdf in df[["terms", "doid"]].iterrows():
        term = subdf["terms"]
        doid = subdf["doid"]
        disease_links.append(
            f'<a href="https://identifiers.org/doid/{doid}">{term}</a>'
        )

    disease_value = ", ".join(disease_links)

    disease_property = next(
        (x for x in network_properties if x["predicateString"] == "disease"), None
    )
    if disease_property:
        disease_property["value"] = disease_value
    else:
        network_properties.append(
            {
                "subNetworkId": "",
                "predicateString": "disease",
                "dataType": "string",
                "value": disease_value,
            }
        )

    my_ndex.set_network_properties(network_id, network_properties)

    # my_ndex.set_network_system_properties(network_id, {"readOnly": True})
    my_ndex.set_read_only(network_id, True)
























