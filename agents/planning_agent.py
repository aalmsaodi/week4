from agents.base_agent import Agent
import json

class PlanningAgent(Agent):
    def __init__(self, name, client, prompt="", gen_kwargs=None):
        super().__init__(name, client, prompt, gen_kwargs)

    async def execute(self, message_history):
        # Check if the user requested to implement a milestone
        user_message = message_history[-1]["content"].lower()
        if "implement milestone" in user_message:
            # Delegate to Implementation Agent
            return "Delegating to Implementation Agent to implement the milestone."
        else:
            # Generate the plan as before
            # Prepare the messages for the assistant
            system_prompt = self._build_system_prompt()
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message_history[-1]["content"]}
            ]

            response = await self.client.chat.completions.create(
                messages=messages,
                stream=False,
                tools=self.tools,
                tool_choice="auto",
                **self.gen_kwargs
            )

            assistant_reply = response.choices[0].message.content

            # Process any function calls (e.g., updating plan.md)
            if response.choices[0].message.function_call:
                function_call = response.choices[0].message.function_call
                function_name = function_call.name
                arguments = json.loads(function_call.arguments)

                if function_name == "updateArtifact":
                    filename = arguments.get("filename")
                    contents = arguments.get("contents")
                    if filename and contents:
                        self._save_artifact(filename, contents)
                        # Add a message to the message history
                        message_history.append({
                            "role": "system",
                            "content": f"The artifact '{filename}' was updated."
                        })

            return assistant_reply

# Add the PLANNING_PROMPT definition
PLANNING_PROMPT = """\
You are a software architect, preparing to build the web page in the image that the user sends. 
Once they send an image, generate a plan, described below, in markdown format.

If the user or reviewer confirms the plan is good, use the available tools to save it as an artifact \
called `plan.md`. If the user has feedback on the plan, revise the plan, and save it using \
the tool again. A tool is available to update the artifact. Your role is only to plan the \
project. You will not implement the plan, and will not write any code.

If the plan has already been saved, no need to save it again unless there is feedback. Do not \
use the tool again if there are no changes.

For the contents of the markdown-formatted plan, create two sections, "Overview" and "Milestones".

In a section labeled "Overview", analyze the image, and describe the elements on the page, \
their positions, and the layout of the major sections.

Using vanilla HTML and CSS, discuss anything about the layout that might have different \
options for implementation. Review pros/cons, and recommend a course of action.

In a section labeled "Milestones", describe an ordered set of milestones for methodically \
building the web page, so that errors can be detected and corrected early. Pay close attention \
to the alignment of elements, and describe clear expectations in each milestone. Do not include \
testing milestones, just implementation.

Milestones should be formatted like this:

 - [ ] 1. This is the first milestone
 - [ ] 2. This is the second milestone
 - [ ] 3. This is the third milestone
"""
