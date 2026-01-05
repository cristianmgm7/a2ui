import os
from dotenv import load_dotenv
from google.adk.agents.llm_agent import Agent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from a2a.types import AgentCard, AgentSkill, AgentCapabilities

# Load environment variables from .env file
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

# Simple question-answering agent for testing A2UI integration
# All MCP tools and sub-agents have been temporarily removed for testing
# Configure Google AI API authentication
api_key = os.getenv('GOOGLE_API_KEY')

agent_config = {
    'model': 'gemini-2.5-flash',
    'name': 'qa_agent',
    'description': 'A helpful assistant that can answer questions and have conversations.',
    'instruction': """You are a friendly and helpful AI assistant.

Your role is to:
- Answer questions clearly and concisely
- Have natural conversations with users
- Provide helpful information on a wide range of topics
- Be polite and professional in all interactions

When responding:
- Keep answers focused and relevant
- Use simple language when possible
- Be honest if you don't know something
- Stay on topic and helpful

This is a test deployment to verify the A2UI (Agent-to-UI) integration works correctly.""",
    'tools': [],  # No tools for now - just pure LLM responses
}

# Note: Google ADK automatically reads GOOGLE_API_KEY from environment variables
# No need to pass api_key as a parameter to the Agent constructor

root_agent = Agent(**agent_config)

# Create a complete AgentSkill with all required fields for Flutter A2A client
qa_skill = AgentSkill(
    id='qa_agent',
    name='Question Answering',
    description='A helpful assistant that can answer questions and have conversations.',
    tags=['qa', 'assistant', 'chat'],
    examples=['Hello', 'Can you help me?', 'What can you do?'],
    input_modes=['text/plain'],
    output_modes=['text/plain'],
)

# Create a complete AgentCard following A2A protocol specification
custom_agent_card = AgentCard(
    name='QA Agent',
    description='A helpful assistant that can answer questions and have conversations.',
    url='http://localhost:8000',
    version='1.0.0',
    default_input_modes=['text/plain'],
    default_output_modes=['text/plain'],
    capabilities=AgentCapabilities(streaming=True),
    skills=[qa_skill],
    supports_authenticated_extended_card=False,
)

# Expose via A2A using to_a2a() with custom agent card
a2a_app = to_a2a(root_agent, port=8000, agent_card=custom_agent_card)

