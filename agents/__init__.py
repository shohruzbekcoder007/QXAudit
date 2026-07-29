"""Agent package — QXAudit host + helper agents (RAG, DocViewer, …)."""

from agents.docviewer_agent import DocViewerAgentService, get_docviewer_agent
from agents.hermes_host import HermesHostService, get_hermes_host
from agents.rag_agent import RAGAgentService, get_rag_agent

__all__ = [
    "HermesHostService",
    "get_hermes_host",
    "RAGAgentService",
    "get_rag_agent",
    "DocViewerAgentService",
    "get_docviewer_agent",
]

# self_improve is imported as `from agents import self_improve`
