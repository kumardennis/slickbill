import openai


openai.api_key = "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"

response = openai.FineTuningJob.list_events(id=job_id, limit=50)

events = response["data"]
events.reverse()

for event in events:
    print(event["message"])

#retrieve fine-tune model id
response = openai.FineTuningJob.retrieve(job_id)
fine_tuned_model_id = response["fine_tuned_model"]

print(response)
print("\nFine-tuned model id:", fine_tuned_model_id)