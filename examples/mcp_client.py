#!/usr/bin/env python3
"""
A simple MCP client example for the Trashfire Dispenser Machine.
This demonstrates how to connect to an MCP session and use tools.
"""

import argparse
import json
import requests
import sys
import time
from typing import Dict, Any, List, Optional


class MCPClient:
    """A simple client for the Model Context Protocol (MCP)."""

    def __init__(self, session_url: str, token: str):
        """Initialize the MCP client.
        
        Args:
            session_url: The URL of the MCP session
            token: The authentication token for the session
        """
        self.session_url = session_url
        self.token = token
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}"
        }

    def list_tools(self) -> List[Dict[str, Any]]:
        """List available tools in the MCP session.
        
        Returns:
            A list of tool definitions
        """
        response = requests.get(
            f"{self.session_url}/tools",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()["tools"]

    def list_resources(self) -> List[Dict[str, Any]]:
        """List available resources in the MCP session.
        
        Returns:
            A list of resource definitions
        """
        response = requests.get(
            f"{self.session_url}/resources",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()["resources"]

    def use_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Use a tool in the MCP session.
        
        Args:
            tool_name: The name of the tool to use
            arguments: The arguments to pass to the tool
            
        Returns:
            The result of the tool execution
        """
        response = requests.post(
            f"{self.session_url}/tools/{tool_name}",
            headers=self.headers,
            json={"arguments": arguments}
        )
        response.raise_for_status()
        return response.json()["result"]

    def access_resource(self, resource_uri: str) -> Dict[str, Any]:
        """Access a resource in the MCP session.
        
        Args:
            resource_uri: The URI of the resource to access
            
        Returns:
            The resource data
        """
        response = requests.get(
            f"{self.session_url}/resources",
            headers=self.headers,
            params={"uri": resource_uri}
        )
        response.raise_for_status()
        return response.json()["data"]


def main():
    parser = argparse.ArgumentParser(description="MCP Client Example")
    parser.add_argument("--session-url", required=True, help="MCP session URL")
    parser.add_argument("--token", required=True, help="Authentication token")
    parser.add_argument("--tool", help="Tool to use")
    parser.add_argument("--arguments", help="Tool arguments (JSON string)")
    parser.add_argument("--resource", help="Resource URI to access")
    parser.add_argument("--list-tools", action="store_true", help="List available tools")
    parser.add_argument("--list-resources", action="store_true", help="List available resources")
    
    args = parser.parse_args()
    
    client = MCPClient(args.session_url, args.token)
    
    if args.list_tools:
        tools = client.list_tools()
        print("Available tools:")
        for tool in tools:
            print(f"  - {tool['name']}: {tool['description']}")
    
    if args.list_resources:
        resources = client.list_resources()
        print("Available resources:")
        for resource in resources:
            print(f"  - {resource['uri']}: {resource['description']}")
    
    if args.tool and args.arguments:
        arguments = json.loads(args.arguments)
        result = client.use_tool(args.tool, arguments)
        print("Tool result:")
        print(json.dumps(result, indent=2))
    
    if args.resource:
        data = client.access_resource(args.resource)
        print("Resource data:")
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()