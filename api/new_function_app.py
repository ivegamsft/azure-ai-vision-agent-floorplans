import logging
import azure.functions as func
import azure.durable_functions as df
import json

app = df.DFApp()

@app.route(route="orchestrators/{functionName}", auth_level=func.AuthLevel.ANONYMOUS)
@app.durable_client_input(client_name="client")
async def http_start(req: func.HttpRequest, client) -> func.HttpResponse:
    function_name = req.route_params.get('functionName')
    instance_id = await client.start_new(function_name)
    response = client.create_check_status_response(req, instance_id)
    return response

@app.orchestration_trigger(context_name="context")
def vision_agent_orchestrator(context):
    name = context.get_input()
    result = yield context.call_activity("activity", name)
    return result

@app.activity_trigger(input_name="name")
def activity(name):
    return f"Hello {name}!"

if __name__ == "__main__":
    app.run()
