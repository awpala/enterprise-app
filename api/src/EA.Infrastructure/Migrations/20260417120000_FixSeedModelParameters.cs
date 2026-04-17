using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EA.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FixSeedModelParameters : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Rename 'iterations' key to 'sampleSize' wherever it exists
            migrationBuilder.Sql(
                """
                UPDATE models
                SET parameters = (parameters - 'iterations') || jsonb_build_object('sampleSize', parameters->'iterations')
                WHERE parameters ? 'iterations';
                """);

            // Rename 'stddev' key to 'stdDev' wherever it exists
            migrationBuilder.Sql(
                """
                UPDATE models
                SET parameters = (parameters - 'stddev') || jsonb_build_object('stdDev', parameters->'stddev')
                WHERE parameters ? 'stddev';
                """);

            // Fix unsupported 'triangular' distributions for specific seed models
            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"exponential"')
                WHERE id = '0afe4fa5-8d61-ada3-1ce8-6eb499110160' AND parameters->>'distribution' = 'triangular';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"uniform"')
                WHERE id = 'fcbd585c-38ee-7a75-b384-81199f8523a1' AND parameters->>'distribution' = 'triangular';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"normal"')
                WHERE id = 'ecbcd2fb-6c1c-cef6-2b65-8a206d84872a' AND parameters->>'distribution' = 'triangular';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"lognormal"')
                WHERE id = '25295baf-d6bd-3d4c-59ce-9c4204821482' AND parameters->>'distribution' = 'triangular';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Reverse: rename 'sampleSize' back to 'iterations'
            migrationBuilder.Sql(
                """
                UPDATE models
                SET parameters = (parameters - 'sampleSize') || jsonb_build_object('iterations', parameters->'sampleSize')
                WHERE parameters ? 'sampleSize';
                """);

            // Reverse: rename 'stdDev' back to 'stddev'
            migrationBuilder.Sql(
                """
                UPDATE models
                SET parameters = (parameters - 'stdDev') || jsonb_build_object('stddev', parameters->'stdDev')
                WHERE parameters ? 'stdDev';
                """);

            // Reverse: set distributions back to 'triangular' for the 4 specific models
            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"triangular"')
                WHERE id = '0afe4fa5-8d61-ada3-1ce8-6eb499110160';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"triangular"')
                WHERE id = 'fcbd585c-38ee-7a75-b384-81199f8523a1';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"triangular"')
                WHERE id = 'ecbcd2fb-6c1c-cef6-2b65-8a206d84872a';
                """);

            migrationBuilder.Sql(
                """
                UPDATE models SET parameters = jsonb_set(parameters, '{distribution}', '"triangular"')
                WHERE id = '25295baf-d6bd-3d4c-59ce-9c4204821482';
                """);
        }
    }
}
