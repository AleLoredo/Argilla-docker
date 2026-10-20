import argilla as rg
from datasets import load_dataset

client = rg.Argilla(
  api_url="http://localhost:6900",
  api_key="argilla.apikey"
)

ds = load_dataset("FineEnvs/openai-math", name="default", split="test")

dataset = client.datasets(name="openai-math", workspace="default")

dataset.records.log(ds, mapping={})