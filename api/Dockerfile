FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
# Copy csproj files first for layer caching
COPY src/EA.Api/EA.Api.csproj src/EA.Api/
COPY src/EA.Domain/EA.Domain.csproj src/EA.Domain/
COPY src/EA.Infrastructure/EA.Infrastructure.csproj src/EA.Infrastructure/
COPY src/EA.Contracts/EA.Contracts.csproj src/EA.Contracts/
RUN dotnet restore src/EA.Api/EA.Api.csproj
COPY src/ src/
RUN dotnet publish src/EA.Api/EA.Api.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "EA.Api.dll"]
