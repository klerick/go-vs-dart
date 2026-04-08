FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS builder

WORKDIR /app
COPY dotnet-service.csproj ./
RUN dotnet restore
COPY Program.cs ./
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine
WORKDIR /app
COPY --from=builder /app/out ./
ENTRYPOINT ["dotnet", "dotnet-service.dll"]
