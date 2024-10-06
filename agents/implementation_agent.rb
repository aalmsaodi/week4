# agents/implementation_agent.py

from agents.base_agent import Agent
import os
import json

class ImplementationAgent(Agent):
    """
    Implementation Agent that executes a specific milestone from the plan.
    """

    def __init__(self, name, client, prompt="", gen_kwargs=None):
        super().__init__(name, client, prompt, gen_kwargs)

    async def execute(self, message_history):
        """
        Executes the implementation of a milestone.
        """
        # Load the plan from plan.md
        plan_file = "artifacts/plan.md"
        if os.path.exists(plan_file):
            with open(plan_file, "r") as file:
                plan_content = file.read()
        else:
            return "No plan found."

        # Extract the next uncompleted milestone
        milestone = self._extract_milestone(plan_content)
        if not milestone:
            return "All milestones are completed."

        # Generate index.html and styles.css based on the milestone
        # Prepare the messages for the assistant
        system_prompt = self._build_system_prompt()
        assistant_prompt = f"Implement the following milestone:\n{milestone}\n\nUpdate index.html and styles.css accordingly. After completion, mark the milestone as completed in plan.md."

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": assistant_prompt}
        ]

        # Call the OpenAI API to generate the implementation
        response = await self.client.chat.completions.create(
            messages=messages,
            stream=False,
            tools=self.tools,
            tool_choice="auto",
            **self.gen_kwargs
        )

        assistant_reply = response.choices[0].message.content

        # Process any function calls (e.g., updating artifacts)
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
        else:
            # If no function call, just return the assistant's reply
            return assistant_reply

        # Mark the milestone as completed
        self._mark_milestone_completed(plan_file, milestone)

        return assistant_reply

    def _extract_milestone(self, plan_content):
        """
        Extracts the next uncompleted milestone from the plan content.
        """
        lines = plan_content.split('\n')
        for line in lines:
            if line.strip().startswith("- [ ]"):
                return line.strip()
        return None

    def _save_artifact(self, filename, content):
        """
        Saves or updates the artifact file in the artifacts folder.
        """
        os.makedirs("artifacts", exist_ok=True)
        with open(os.path.join("artifacts", filename), "w") as file:
            file.write(content)

    def _mark_milestone_completed(self, plan_file, milestone):
        """
        Marks the milestone as completed in the plan.md file.
        """
        with open(plan_file, "r") as file:
            content = file.read()

        updated_content = content.replace(milestone, milestone.replace("- [ ]", "- [x]"))

        with open(plan_file, "w") as file:
            file.write(updated_content)


# agents/implementation_agent.py

IMPLEMENTATION_PROMPT = """\
You are a software developer tasked with implementing milestones from a project plan.

Instructions:

- Implement the milestone provided by the user.
- Update `index.html` and `styles.css` in the artifacts folder according to the milestone requirements.
- Use vanilla HTML and CSS.
- After completing the implementation, mark the milestone as completed in `plan.md` by replacing `- [ ]` with `- [x]`.

Remember:

- Do not modify any other milestones.
- Ensure your code is properly formatted and error-free.
- Provide a brief summary of the changes you made.
"""
