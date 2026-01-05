import os
from dotenv import load_dotenv
from google.adk.agents.llm_agent import Agent
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams, StdioServerParameters
from google.adk.auth import AuthCredential, AuthCredentialTypes, OAuth2Auth
from fastapi.openapi.models import OAuth2, OAuthFlows, OAuthFlowAuthorizationCode
from google.adk.tools.openapi_tool.openapi_spec_parser.openapi_toolset import OpenAPIToolset
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from a2a.types import AgentCard, AgentSkill, AgentCapabilities  # pyright: ignore[reportMissingImports]
from pathlib import Path
import json
import os

# Load environment variables from .env file
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

# Load OpenAPI specifications
google_calendar_spec_path = Path(__file__).parent.parent.parent / "google_calendar_openapi.yaml"
GOOGLE_CALENDAR_SPEC = None
if google_calendar_spec_path.exists():
    with open(google_calendar_spec_path, 'r') as f:
        GOOGLE_CALENDAR_SPEC = f.read()
    print("Loaded Google Calendar OpenAPI specification")
else:
    print("Warning: Google Calendar OpenAPI spec file not found")

def load_instruction(filename: str) -> str:
    """Load agent instruction from a text file."""
    instruction_path = Path(__file__).parent.parent / "instructions" / filename
    if instruction_path.exists():
        with open(instruction_path, 'r') as f:
            return f.read().strip()
    else:
        # Return a default instruction if file not found
        return f"Default instruction for {filename}"

# Create sub-agents based on your complex agent structure
github_agent = Agent(
    model='gemini-2.5-flash',
    name='github_agent',
    description='A GitHub assistant for repository and issue management.',
    instruction=load_instruction('github_agent.txt'),
    tools=[],  # Start simple, add tools later
)

# Create Carbon Voice agent with MCP tools
carbon_voice_tools = []
try:
    carbon_voice_tools.append(
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='npx',
                    args=["-y", "@carbonvoice/cv-mcp-server"],
                    env={
                        "LOG_LEVEL": "info"
                    },
                ),
            ),
            auth_scheme=OAuth2(
                flows=OAuthFlows(
                    authorizationCode=OAuthFlowAuthorizationCode(
                        authorizationUrl="https://api.carbonvoice.app/oauth/authorize",
                        tokenUrl="https://api.carbonvoice.app/oauth/token",
                        scopes={
                            "files:read": "Read files",
                            "files:write": "Write files"
                        },
                    )
                )
            ),
            auth_credential=AuthCredential(
                auth_type=AuthCredentialTypes.OAUTH2,
                oauth2=OAuth2Auth(
                    client_id=os.getenv("CARBON_CLIENT_ID", "YOUR_CARBON_CLIENT_ID"),
                    client_secret=os.getenv("CARBON_CLIENT_SECRET", "YOUR_CARBON_CLIENT_SECRET"),
                    redirect_uri=os.getenv("CARBON_REDIRECT_URI", "https://cristianmgm7.github.io/carbon-console-auth/"),
                )
            )
        )
    )
    print("Added Carbon Voice MCP tools")
except Exception as e:
    print(f"Warning: Could not add Carbon Voice MCP tools: {e}")

carbon_voice_agent = Agent(
    model='gemini-2.5-flash',
    name='carbon_voice_agent',
    description='A communication specialist for Carbon Voice messaging.',
    instruction=load_instruction('carbon_voice_agent.txt'),
    tools=carbon_voice_tools,
)

# Create Atlassian agent with MCP tools
atlassian_tools = []
try:
    atlassian_tools.append(
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command="npx",
                    args=[
                        "-y",
                        "mcp-remote",
                        "https://mcp.atlassian.com/v1/sse",
                    ]
                ),
                timeout=30,
            ),
        )
    )
    print("Added Atlassian MCP tools")
except Exception as e:
    print(f"Warning: Could not add Atlassian MCP tools: {e}")

atlassian_agent = Agent(
    model='gemini-2.5-flash',
    name='atlassian_agent',
    description='An assistant for Atlassian tools like Jira and Confluence.',
    instruction=load_instruction('atlassian_agent.txt'),
    tools=atlassian_tools,
)

# Create Google Calendar agent with OpenAPI tools
google_calendar_tools = []
if GOOGLE_CALENDAR_SPEC:
    try:
        google_calendar_tools.append(
            OpenAPIToolset(
                spec_str=GOOGLE_CALENDAR_SPEC,
                spec_str_type='yaml',
                auth_scheme=OAuth2(
                    flows=OAuthFlows(
                        authorizationCode=OAuthFlowAuthorizationCode(
                            authorizationUrl="https://accounts.google.com/o/oauth2/auth",
                            tokenUrl="https://oauth2.googleapis.com/token",
                            scopes={
                                "https://www.googleapis.com/auth/calendar": "See, edit, share, and permanently delete all the calendars you can access using Google Calendar",
                                "https://www.googleapis.com/auth/calendar.events": "View and edit events on all your calendars",
                            },
                        )
                    )
                ),
                auth_credential=AuthCredential(
                    auth_type=AuthCredentialTypes.OAUTH2,
                    oauth2=OAuth2Auth(
                        client_id=os.getenv("GOOGLE_CLIENT_ID", "YOUR_GOOGLE_CLIENT_ID"),
                        client_secret=os.getenv("GOOGLE_CLIENT_SECRET", "YOUR_GOOGLE_CLIENT_SECRET"),
                        redirect_uri=os.getenv("GOOGLE_REDIRECT_URI", "https://cristianmgm7.github.io/carbon-console-auth/"),
                    )
                )
            )
        )
        print("Added Google Calendar OpenAPI tools")
    except Exception as e:
        print(f"Warning: Could not add Google Calendar OpenAPI tools: {e}")

google_calendar_agent = Agent(
    model='gemini-2.5-flash',
    name='google_calendar_agent',
    description='A calendar assistant for managing events and schedules.',
    instruction=load_instruction('google_calendar_agent.txt'),
    tools=google_calendar_tools,
)

# Create root orchestrator agent with sub_agents
root_agent = Agent(
    model='gemini-2.5-flash',
    name='root_orchestrator',
    description='Main orchestrator agent that coordinates GitHub, Carbon Voice, Atlassian, and Google Calendar operations.',
    instruction=load_instruction('root_agent.txt'),
    sub_agents=[github_agent, carbon_voice_agent, atlassian_agent, google_calendar_agent],
)

# Create comprehensive AgentSkills for all sub-agents
skills = []

# GitHub skill
github_skill = AgentSkill(
    id='github_agent',
    name='GitHub Operations',
    description='Manage GitHub repositories, issues, and pull requests.',
    tags=['github', 'repositories', 'issues', 'pull-requests'],
    examples=['List my repositories', 'Create an issue', 'Check pull request status'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)
skills.append(github_skill)

# Carbon Voice skill
carbon_voice_skill = AgentSkill(
    id='carbon_voice_agent',
    name='Carbon Voice Communication',
    description='Handle Carbon Voice messaging platform operations.',
    tags=['carbon-voice', 'messaging', 'communication'],
    examples=['Send a message', 'Check message status', 'List conversations'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)
skills.append(carbon_voice_skill)

# Atlassian skill
atlassian_skill = AgentSkill(
    id='atlassian_agent',
    name='Atlassian Tools',
    description='Manage Jira, Confluence, and other Atlassian products.',
    tags=['atlassian', 'jira', 'confluence'],
    examples=['Create a Jira ticket', 'Search Confluence pages', 'Update issue status'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)
skills.append(atlassian_skill)

# Google Calendar skill
google_calendar_skill = AgentSkill(
    id='google_calendar_agent',
    name='Google Calendar Management',
    description='Manage calendar events, schedules, and appointments.',
    tags=['calendar', 'events', 'scheduling'],
    examples=['Schedule a meeting', 'Check my calendar', 'Create an event'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)
skills.append(google_calendar_skill)

# Root orchestrator skill
orchestrator_skill = AgentSkill(
    id='root_orchestrator',
    name='Multi-Platform Orchestration',
    description='Coordinate operations across GitHub, Carbon Voice, Atlassian, and Google Calendar.',
    tags=['orchestrator', 'multi-platform', 'coordination'],
    examples=['Help me with my workflow', 'Coordinate a project', 'Check all my tools'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)
skills.append(orchestrator_skill)

# Create comprehensive AgentCard for A2A protocol
custom_agent_card = AgentCard(
    name='Carbon Voice Console Agent',
    description='A comprehensive AI assistant that orchestrates operations across GitHub, Carbon Voice messaging, Atlassian tools (Jira/Confluence), and Google Calendar with OAuth authentication.',
    url='http://localhost:8000',
    version='2.0.0',
    default_input_modes=['text/plain'],
    default_output_modes=['text/plain'],
    capabilities=AgentCapabilities(streaming=True),
    skills=skills,
    supports_authenticated_extended_card=True,  # Enable OAuth flows for MCP and OpenAPI tools
)

# Expose via A2A using to_a2a() with comprehensive agent card
a2a_app = to_a2a(root_agent, port=8000, agent_card=custom_agent_card)

