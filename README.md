# AutomaticShrinkLDFVerification
This script make LOG Shrinks for each database with "sp_MSforeachdb" procedure. Before making this Shrinks, the script make some validations, like Primary replic database (Always ON), Online database, log_reuse_wait_desc = ''NOTHING'' and is_read_only = 0
