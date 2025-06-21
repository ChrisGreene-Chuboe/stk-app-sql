# Chuck-Stack Nushell Modules
#
# This file exports all available chuck-stack modules for database interaction.
# Each module provides nushell commands for specific chuck-stack functionality.

# PostgreSQL command execution with structured output
export use stk_psql *

# Utility functions for chuck-stack modules
export use stk_utility *

# Event logging and retrieval for audit trails and system monitoring  
export use stk_event *

# Request tracking and management for follow-up actions
export use stk_request *

# Todo list management built on hierarchical requests
export use stk_todo *

# Item management for products, services, accounts, and charges
export use stk_item *

# Project management with hierarchical structure and line items
export use stk_project *

# Tag system for flexible metadata attachment with JSON Schema validation
export use stk_tag *

# AI-powered text transformation utilities for chuck-stack
export use stk_ai *

# Address management with AI-powered natural language processing
export use stk_address *
