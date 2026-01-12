package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/your-org/my-media-stack/paas"
)

func main() {
	var (
		inputFile    = flag.String("input", "", "Input file to load")
		outputFile   = flag.String("output", "", "Output file to save")
		fromPlatform = flag.String("from", "", "Source platform (docker-compose, nomad, kubernetes)")
		toPlatform   = flag.String("to", "", "Target platform (docker-compose, nomad, kubernetes)")
		validate     = flag.Bool("validate", false, "Validate the loaded application")
		listServices = flag.Bool("list-services", false, "List all services in the application")
		mergeFiles   = flag.String("merge", "", "Comma-separated list of files to merge")
		workDir      = flag.String("workdir", "/tmp/paas", "Working directory for temporary files")
		deploy       = flag.Bool("deploy", false, "Deploy to infra Go code")
		infraPath    = flag.String("infra-path", "../infra", "Path to infra directory for deployment")
	)

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "PaaS - Platform as a Service converter\n\n")
		fmt.Fprintf(os.Stderr, "Usage: %s [options]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  # Convert docker-compose.yml to nomad.hcl\n")
		fmt.Fprintf(os.Stderr, "  %s -input docker-compose.yml -output nomad.hcl -from docker-compose -to nomad\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Validate a docker-compose file\n")
		fmt.Fprintf(os.Stderr, "  %s -input docker-compose.yml -validate\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # List services in a nomad file\n")
		fmt.Fprintf(os.Stderr, "  %s -input nomad.hcl -list-services\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Merge multiple compose files\n")
		fmt.Fprintf(os.Stderr, "  %s -merge compose/app.yml,compose/db.yml -output merged.yml\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Deploy docker-compose.yml to infra Go code\n")
		fmt.Fprintf(os.Stderr, "  %s -input docker-compose.yml -deploy\n\n", os.Args[0])
	}

	flag.Parse()

	// Create PaaS instance
	config := &paas.PaaSConfig{
		WorkDir: *workDir,
	}
	paasInstance := paas.New(config)

	// Handle merge operation
	if *mergeFiles != "" {
		files := strings.Split(*mergeFiles, ",")
		var apps []*paas.Application

		for _, file := range files {
			file = strings.TrimSpace(file)
			app, err := paasInstance.LoadFile(file)
			if err != nil {
				log.Fatalf("Failed to load %s: %v", file, err)
			}
			apps = append(apps, app)
		}

		merged, err := paasInstance.MergeApplications(apps...)
		if err != nil {
			log.Fatalf("Failed to merge applications: %v", err)
		}

		if *outputFile != "" {
			err = paasInstance.SaveFile(merged, *outputFile)
			if err != nil {
				log.Fatalf("Failed to save merged file: %v", err)
			}
			fmt.Printf("Merged %d applications into %s\n", len(apps), *outputFile)
		} else {
			fmt.Printf("Merged application: %s\n", merged.String())
		}
		return
	}

	// Handle deploy operation (integration with infra)
	if *deploy {
		if *inputFile == "" {
			log.Fatalf("Input file required for deployment")
		}

		app, err := paasInstance.LoadFile(*inputFile)
		if err != nil {
			log.Fatalf("Failed to load %s: %v", *inputFile, err)
		}

		integration := paas.NewInfraIntegration(*infraPath)

		err = integration.DeployToInfra(app, "services_generated")
		if err != nil {
			log.Fatalf("Failed to deploy to infra: %v", err)
		}

		fmt.Printf("Successfully deployed %d services to infra\n", len(app.Services))
		return
	}

	// Handle single file operations
	if *inputFile == "" {
		flag.Usage()
		os.Exit(1)
	}

	// Load input file
	app, err := paasInstance.LoadFile(*inputFile)
	if err != nil {
		log.Fatalf("Failed to load %s: %v", *inputFile, err)
	}

	fmt.Printf("Loaded %s with %d services\n", *inputFile, len(app.Services))

	// Validate if requested
	if *validate {
		if err := paasInstance.Validate(app); err != nil {
			log.Fatalf("Validation failed: %v", err)
		}
		fmt.Println("✓ Validation passed")
	}

	// List services if requested
	if *listServices {
		fmt.Println("Services:")
		for _, name := range paasInstance.ListServices(app) {
			service := app.Services[name]
			fmt.Printf("  - %s (%s)\n", name, service.Image)
		}
	}

	// Handle conversion
	if *toPlatform != "" {
		from := detectPlatform(*inputFile)
		if *fromPlatform != "" {
			from = parsePlatform(*fromPlatform)
		}
		to := parsePlatform(*toPlatform)

		fmt.Printf("Converting %s -> %s...\n", from, to)

		converted, err := paasInstance.Convert(app, from, to)
		if err != nil {
			log.Fatalf("Conversion failed: %v", err)
		}

		if *outputFile != "" {
			err = paasInstance.SaveFile(converted, *outputFile)
			if err != nil {
				log.Fatalf("Failed to save %s: %v", *outputFile, err)
			}
			fmt.Printf("Converted to %s\n", *outputFile)
		} else {
			content, err := paasInstance.SaveContent(converted, to)
			if err != nil {
				log.Fatalf("Failed to serialize: %v", err)
			}
			fmt.Println("Converted content:")
			fmt.Println(content)
		}
	} else if *outputFile != "" {
		// Just save in original format
		err = paasInstance.SaveFile(app, *outputFile)
		if err != nil {
			log.Fatalf("Failed to save %s: %v", *outputFile, err)
		}
		fmt.Printf("Saved to %s\n", *outputFile)
	} else if !*validate && !*listServices {
		// Default: show application info
		fmt.Println(app.String())
	}
}

func detectPlatform(filename string) paas.Platform {
	ext := strings.ToLower(filepath.Ext(filename))

	switch ext {
	case ".yml", ".yaml":
		if strings.Contains(filename, "k8s") || strings.Contains(filename, "kubernetes") {
			return paas.PlatformKubernetes
		}
		return paas.PlatformDockerCompose
	case ".hcl":
		return paas.PlatformNomad
	default:
		return paas.PlatformDockerCompose
	}
}

func parsePlatform(platform string) paas.Platform {
	switch strings.ToLower(platform) {
	case "docker-compose", "docker", "compose":
		return paas.PlatformDockerCompose
	case "nomad", "hcl":
		return paas.PlatformNomad
	case "kubernetes", "k8s", "k8":
		return paas.PlatformKubernetes
	case "helm":
		return paas.PlatformHelm
	default:
		log.Fatalf("Unknown platform: %s", platform)
		return paas.PlatformDockerCompose
	}
}
