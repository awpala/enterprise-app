using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EA.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddModelRunSampleData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "sample_data",
                table: "model_runs",
                type: "jsonb",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "sample_data",
                table: "model_runs");
        }
    }
}
