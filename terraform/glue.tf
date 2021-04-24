resource "aws_glue_catalog_database" "aws_glue_database" {
  name = "beer-glue-database"
}

resource "aws_glue_catalog_table" "aws_glue_table" {
  name          = "beer-glue-table"
  database_name = "${aws_glue_catalog_database.aws_glue_database.name}"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.clean_bucket.bucket}"
    input_format  = "${var.storage_input_format}"
    output_format = "${var.storage_output_format}"

    columns {
        name = "id"
        type = "int"
    }

    columns {
        name = "name"
        type = "string"
    }

    columns {
        name = "abv"
        type = "float"
    }
    
    columns {
        name = "ibu"
        type = "float"
     }

    columns {
        name = "target_fg"
        type = "float"
    }

    columns {
        name = "target_og"
        type = "float"
    }

    columns {
        name = "ebc"
        type = "float"
    }
    
    columns {
        name = "srm"
        type = "float"
    }
    
    columns  {
        name = "ph"
        type = "float"
    }
    
  }
}