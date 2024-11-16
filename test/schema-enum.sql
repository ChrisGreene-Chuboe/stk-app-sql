---- the following represent all enum values ----

--select * from api.enum_value
SET
Time: 0.156 ms
SET
Time: 0.056 ms
        enum_name         |    enum_value    |                      comment                       
--------------------------+------------------+----------------------------------------------------
 actor_type               | NONE             | General purpose with no automation or validation
 attribute_tag_type       | NONE             | General purpose with no automation or validation
 attribute_tag_type       | CONTRACT         | [NULL]
 attribute_tag_type       | EMAIL            | [NULL]
 attribute_tag_type       | PHONE            | [NULL]
 attribute_tag_type       | SNS              | [NULL]
 attribute_tag_type       | NOTE             | [NULL]
 attribute_tag_type       | TRANSLATION      | [NULL]
 attribute_tag_type       | ACTIVITY         | [NULL]
 attribute_tag_type       | INTEREST_AREA    | [NULL]
 attribute_tag_type       | ATTACHMENT       | [NULL]
 attribute_tag_type       | LOCATION         | [NULL]
 attribute_tag_type       | DATE_START       | [NULL]
 attribute_tag_type       | DATE_END         | [NULL]
 attribute_tag_type       | DATE_RANGE       | [NULL]
 attribute_tag_type       | SHARE            | [NULL]
 attribute_tag_type       | ERROR            | [NULL]
 attribute_tag_type       | TABLE            | [NULL]
 attribute_tag_type       | COLUMN           | Column attributes with no automation or validation
 statistic_type           | RECORD_SUMMARY   | Provides a summary of the record for easy lookup
 statistic_type           | GRAND_TOTAL      | [NULL]
 statistic_type           | TAX_TOTAL        | [NULL]
 statistic_type           | LIFETIME_REVENUE | [NULL]
 statistic_type           | YTD_REVENUE      | [NULL]
 system_config_level_type | SYSTEM           | [NULL]
 system_config_level_type | TENANT           | [NULL]
 system_config_level_type | ENTITY           | [NULL]
 system_config_level_type | ROLE             | [NULL]
 system_config_level_type | USER             | [NULL]
 wf_request_type          | NOTE             | Action purpose with no automation or validation
 wf_request_type          | DISCUSS          | [NULL]
 wf_request_type          | NOTICE           | [NULL]
 wf_request_type          | ACTION           | [NULL]
 wf_request_type          | TODO             | [NULL]
 wf_request_type          | CHECKLIST        | Action purpose with no automation or validation
(35 rows)

Time: 3.088 ms
