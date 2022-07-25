/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"context"
	"fmt"
	"go/types"
	"opcap/internal/logger"
	"opcap/internal/operator"
	"os"

	pkgserverv1 "github.com/operator-framework/operator-lifecycle-manager/pkg/package-server/apis/operators/v1"

	"opcap/internal/capability"

	"github.com/spf13/cobra"
)

// TODO: provide godoc compatible comment for checkCmd
var checkCmd = &cobra.Command{
	Use: "check",
	// TODO: provide Short description for check command
	Short: "",
	// TODO: provide Long description for check command
	Long: ``,
	PreRunE: func(cmd *cobra.Command, args []string) error {
		psc, err := operator.NewOpCapClient()
		if err != nil {
			return types.Error{Msg: "Unable to create OpCap client."}
		}
		var packageManifestList pkgserverv1.PackageManifestList
		err = psc.ListPackageManifests(context.TODO(), &packageManifestList)
		if err != nil {
			return types.Error{Msg: "Unable to list PackageManifests."}
		}

		if len(packageManifestList.Items) == 0 {
			return types.Error{Msg: "No PackageManifests returned from PackageServer."}
		}

		if checkflags.ListPackages {
			for _, packageManifest := range packageManifestList.Items {
				fmt.Println(packageManifest.Name)
			}
			os.Exit(0)
		}

		return nil
	},
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("check called")

		// Build auditor by catalog
		auditor, err := capability.BuildAuditorByCatalog(checkflags.CatalogSource, checkflags.CatalogSourceNamespace, checkflags.AuditPlan)
		if err != nil {
			logger.Sugar.Fatal("Unable to build auditor")
		}
		// run all dynamically built audits in the auditor workqueue
		auditor.RunAudits()
	},
}

type CheckCommandFlags struct {
	AuditPlan              []string `json:"auditPlan"`
	CatalogSource          string   `json:"catalogsource"`
	CatalogSourceNamespace string   `json:"catalogsourcenamespace"`
	ListPackages           bool     `json:"listPackages"`
}

var checkflags CheckCommandFlags

func init() {

	var defaultAuditPlan = []string{"OperatorInstall", "OperatorCleanUp"}

	rootCmd.AddCommand(checkCmd)
	flags := checkCmd.Flags()

	flags.StringVar(&checkflags.CatalogSource, "catalogsource", "certified-operators",
		"")
	flags.StringVar(&checkflags.CatalogSourceNamespace, "catalogsourcenamespace", "openshift-marketplace",
		"")
	flags.StringArrayVar(&checkflags.AuditPlan, "auditplan", defaultAuditPlan, "audit plan is the ordered list of operator test functions to be called during a capability audit.")
	flags.BoolVar(&checkflags.ListPackages, "list-packages", false, "list packages in the catalog")
}
